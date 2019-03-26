import Foundation
import HSHDWalletKit
import RxSwift
import BigInt
import HSCryptoKit

class DataProvider {
    private let disposeBag = DisposeBag()

    private let storage: IStorage
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

    init(storage: IStorage, addressManager: IAddressManager, addressConverter: IAddressConverter, paymentAddressParser: IPaymentAddressParser, unspentOutputProvider: IUnspentOutputProvider, transactionCreator: ITransactionCreator, transactionBuilder: ITransactionBuilder, network: INetwork, debounceTime: Double = 0.5) {
        self.storage = storage
        self.addressManager = addressManager
        self.addressConverter = addressConverter
        self.paymentAddressParser = paymentAddressParser
        self.unspentOutputProvider = unspentOutputProvider
        self.transactionCreator = transactionCreator
        self.transactionBuilder = transactionBuilder
        self.network = network
        self.balance = unspentOutputProvider.balance
        self.lastBlockInfo = storage.lastBlock.map { blockInfo(fromBlock: $0) }

        balanceUpdateSubject.debounce(debounceTime, scheduler: ConcurrentDispatchQueueScheduler(qos: .background)).subscribe(onNext: {
            self.balance = unspentOutputProvider.balance
        }).disposed(by: disposeBag)
    }

    private func transactionInfo(fromTransaction transaction: Transaction) -> TransactionInfo {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddressInfo]()
        var toAddresses = [TransactionAddressInfo]()

        for input in storage.inputs(ofTransaction: transaction) {
            var mine = false

            if let previousOutput = storage.previousOutput(ofInput: input) {
                if previousOutput.publicKeyPath != nil {
                    totalMineInput += previousOutput.value
                    mine = true
                }
            }

            if let address = input.address {
                fromAddresses.append(TransactionAddressInfo(address: address, mine: mine))
            }
        }

        for output in storage.outputs(ofTransaction: transaction) {
            var mine = false

            if output.publicKeyPath != nil {
                totalMineOutput += output.value
                mine = true
            }

            if let address = output.address {
                toAddresses.append(TransactionAddressInfo(address: address, mine: mine))
            }
        }

        let amount = totalMineOutput - totalMineInput

        return TransactionInfo(
                transactionHash: transaction.dataHashReversedHex,
                from: fromAddresses,
                to: toAddresses,
                amount: amount,
                blockHeight: transaction.block(storage: storage)?.height,
                timestamp: transaction.timestamp
        )
    }

    private func blockInfo(fromBlock block: Block) -> BlockInfo {
        return BlockInfo(
                headerHash: block.headerHashReversedHex,
                height: block.height,
                timestamp: block.timestamp
        )
    }

    private var feeRate: FeeRate {
        return storage.feeRate ?? FeeRate.defaultFeeRate
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
            var transactions = self.storage.transactions(sortedBy: Transaction.Columns.timestamp, secondSortedBy:  Transaction.Columns.order, ascending: false)

            if let fromHash = fromHash, let fromTransaction = self.storage.transaction(byHashHex: fromHash) {
                transactions = transactions.filter { transaction in
                    return transaction.timestamp < fromTransaction.timestamp ||
                            (transaction.timestamp == fromTransaction.timestamp && transaction.order < fromTransaction.order)
                }
            }

            if let limit = limit {
                transactions = Array(transactions.prefix(limit))
            }

            observer(.success(transactions.map() { self.transactionInfo(fromTransaction: $0) }))
            return Disposables.create()
        }
    }

    func send(to address: String, value: Int) throws {
        try transactionCreator.create(to: address, value: value, feeRate: feeRate.medium, senderPay: true)
    }

    func parse(paymentAddress: String) -> BitcoinPaymentData {
        return paymentAddressParser.parse(paymentAddress: paymentAddress)
    }

    func validate(address: String) throws {
        _ = try addressConverter.convert(address: address)
    }

    func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try transactionBuilder.fee(for: value, feeRate: feeRate.medium, senderPay: senderPay, address: toAddress)
    }

    var receiveAddress: String {
        return (try? addressManager.receiveAddress()) ?? ""
    }

    var debugInfo: String {
        var lines = [String]()

        let transactions = storage.transactions(sortedBy: Transaction.Columns.timestamp, secondSortedBy: Transaction.Columns.order, ascending: false)
        let pubKeys = storage.publicKeys()

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
        lines.append("TRANSACTIONS COUNT: \(transactions.count)")
        lines.append("BLOCK COUNT: \(storage.blocksCount)")
        if let block = storage.firstBlock {
            lines.append("First Block: \(block.height) --- \(block.headerHashReversedHex)")
        }
        if let block = storage.lastBlock {
            lines.append("Last Block: \(block.height) --- \(block.headerHashReversedHex)")
        }

        return lines.joined(separator: "\n")
    }

}
