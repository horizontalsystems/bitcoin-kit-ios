import Foundation
import HSHDWalletKit
import RealmSwift
import RxSwift
import BigInt
import HSCryptoKit

class DataProvider {
    private let disposeBag = DisposeBag()

    private let feeRateManager: IFeeRateManager
    private let realmFactory: IRealmFactory
    private let addressManager: IAddressManager
    private let addressConverter: IAddressConverter
    private let paymentAddressParser: IPaymentAddressParser
    private let unspentOutputProvider: IUnspentOutputProvider
    private let transactionCreator: ITransactionCreator
    private let transactionBuilder: ITransactionBuilder
    private let network: INetwork

    private let balanceUpdateSubject = PublishSubject<Void>()

    public var balance: Int = 0 {
        didSet {
            if !(oldValue == balance) {
                delegate?.balanceUpdated(balance: balance)
            }
        }
    }
    public var lastBlockInfo: BlockInfo? = nil

    weak var delegate: IDataProviderDelegate?

    init(realmFactory: IRealmFactory, addressManager: IAddressManager, addressConverter: IAddressConverter, paymentAddressParser: IPaymentAddressParser, unspentOutputProvider: IUnspentOutputProvider, feeRateManager: IFeeRateManager, transactionCreator: ITransactionCreator, transactionBuilder: ITransactionBuilder, network: INetwork, debounceTime: Double = 0.5) {
        self.realmFactory = realmFactory
        self.addressManager = addressManager
        self.addressConverter = addressConverter
        self.paymentAddressParser = paymentAddressParser
        self.unspentOutputProvider = unspentOutputProvider
        self.feeRateManager = feeRateManager
        self.transactionCreator = transactionCreator
        self.transactionBuilder = transactionBuilder
        self.network = network
        self.balance = unspentOutputProvider.balance
        self.lastBlockInfo = realmFactory.realm.objects(Block.self).sorted(byKeyPath: "height").last.map { blockInfo(fromBlock: $0) }

        balanceUpdateSubject.debounce(debounceTime, scheduler: ConcurrentDispatchQueueScheduler(qos: .background)).subscribe(onNext: {
            self.balance = unspentOutputProvider.balance
        }).disposed(by: disposeBag)
    }

    private func transactionInfo(fromTransaction transaction: Transaction) -> TransactionInfo {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddressInfo]()
        var toAddresses = [TransactionAddressInfo]()

        for input in transaction.inputs {
            if let previousOutput = input.previousOutput {
                if previousOutput.publicKey != nil {
                    totalMineInput += previousOutput.value
                }
            }

            let mine = input.previousOutput?.publicKey != nil

            if let address = input.address {
                fromAddresses.append(TransactionAddressInfo(address: address, mine: mine))
            }
        }

        for output in transaction.outputs {
            var mine = false

            if output.publicKey != nil {
                totalMineOutput += output.value
                mine = true
            }

            if let address = output.address {
                toAddresses.append(TransactionAddressInfo(address: address, mine: mine))
            }
        }

        let amount = totalMineOutput - totalMineInput

        return TransactionInfo(
                transactionHash: transaction.reversedHashHex,
                from: fromAddresses,
                to: toAddresses,
                amount: amount,
                blockHeight: transaction.block?.height,
                timestamp: transaction.timestamp
        )
    }

    private func blockInfo(fromBlock block: Block) -> BlockInfo {
        return BlockInfo(
                headerHash: block.reversedHeaderHashHex,
                height: block.height,
                timestamp: block.header?.timestamp
        )
    }

}

extension DataProvider: IBlockchainDataListener {

    func onUpdate(updated: [Transaction], inserted: [Transaction]) {
        delegate?.transactionsUpdated(inserted: inserted.map { transactionInfo(fromTransaction: $0) },
                                      updated: updated.map { transactionInfo(fromTransaction: $0) })

        balanceUpdateSubject.onNext(())
    }

    func onDelete(transactionHashes: [String]) {
        delegate?.transactionsDeleted(hashes: transactionHashes)

        balanceUpdateSubject.onNext(())
    }

    func onInsert(block: Block) {
        if block.height > (lastBlockInfo?.height ?? 0) {
            let lastBlockInfo = blockInfo(fromBlock: block)
            self.lastBlockInfo = lastBlockInfo
            delegate?.lastBlockInfoUpdated(lastBlockInfo: lastBlockInfo)

            balanceUpdateSubject.onNext(())
        }
    }

}

extension DataProvider: IDataProvider {

    func transactions(fromHash: String?, limit: Int?) -> Single<[TransactionInfo]> {
        return Single.create { observer in
            let realm = self.realmFactory.realm
            var transactions = realm.objects(Transaction.self)
                    .sorted(by: [SortDescriptor(keyPath: "timestamp", ascending: false), SortDescriptor(keyPath: "order", ascending: false)])

            if let fromHash = fromHash, let fromTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", fromHash).first {
                transactions = transactions.filter(
                        "timestamp < %@ OR (timestamp = %@ AND order < %@)",
                        fromTransaction.timestamp,
                        fromTransaction.timestamp,
                        fromTransaction.order
                )
            }

            let results: [Transaction]
            if let limit = limit {
                results = Array(transactions.prefix(limit))
            } else {
                results = Array(transactions)
            }

            observer(.success(results.map() { self.transactionInfo(fromTransaction: $0) }))
            return Disposables.create()
        }
    }

    func send(to address: String, value: Int) throws {
        try transactionCreator.create(to: address, value: value, feeRate: feeRateManager.mediumValue, senderPay: true)
    }

    func parse(paymentAddress: String) -> BitcoinPaymentData {
        return paymentAddressParser.parse(paymentAddress: paymentAddress)
    }

    func validate(address: String) throws {
        _ = try addressConverter.convert(address: address)
    }

    func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try transactionBuilder.fee(for: value, feeRate: feeRateManager.mediumValue, senderPay: senderPay, address: toAddress)
    }

    var receiveAddress: String {
        return (try? addressManager.receiveAddress()) ?? ""
    }

    var debugInfo: String {
        var lines = [String]()

        let realm = realmFactory.realm

        let blocks = realm.objects(Block.self).sorted(byKeyPath: "height")
        let pubKeys = realm.objects(PublicKey.self)

        for pubKey in pubKeys {
            var bechAddress: String?
            if network is BitcoinCashMainNet || network is BitcoinCashTestNet {
                bechAddress = try? addressConverter.convert(keyHash: pubKey.keyHash, type: .p2pkh).stringValue
            } else {
                bechAddress = try? addressConverter.convert(keyHash: OpCode.scriptWPKH(pubKey.keyHash), type: .p2wpkh).stringValue
            }

            lines.append("\(pubKey.account) --- \(pubKey.index) --- \(pubKey.external) --- hash: \(pubKey.keyHash.hex) --- p2wkph(SH) hash: \(pubKey.scriptHashForP2WPKH.hex)")
            lines.append("legacy: \(addressConverter.convertToLegacy(keyHash: pubKey.keyHash, version: network.pubKeyHash, addressType: .pubKeyHash).stringValue) --- bech32: \(bechAddress ?? "none") --- SH(WPKH): \(addressConverter.convertToLegacy(keyHash: pubKey.scriptHashForP2WPKH, version: network.scriptHash, addressType: .scriptHash).stringValue) \n")
        }
        lines.append("PUBLIC KEYS COUNT: \(pubKeys.count)")

        lines.append("BLOCK COUNT: \(blocks.count)")
        if let block = blocks.first {
            lines.append("First Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }
        if let block = blocks.last {
            lines.append("Last Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }

        return lines.joined(separator: "\n")
    }

}
