import Foundation
import HSHDWalletKit
import RealmSwift
import RxSwift
import BigInt
import HSCryptoKit

class DataProvider {
    private let disposeBag = DisposeBag()
    private var knownBestBlockHeight: Int = 0

    private let realmFactory: IRealmFactory
    private let addressManager: IAddressManager
    private let addressConverter: IAddressConverter
    private let transactionCreator: ITransactionCreator
    private let transactionBuilder: ITransactionBuilder
    private let network: INetwork

    private var unspentOutputsNotificationToken: NotificationToken?
    private var transactionsNotificationToken: NotificationToken?
    private var blocksNotificationToken: NotificationToken?

    weak var delegate: DataProviderDelegate?

    init(realmFactory: IRealmFactory, addressManager: IAddressManager, addressConverter: IAddressConverter, transactionCreator: ITransactionCreator, transactionBuilder: ITransactionBuilder, network: INetwork) {
        self.realmFactory = realmFactory
        self.addressManager = addressManager
        self.addressConverter = addressConverter
        self.transactionCreator = transactionCreator
        self.transactionBuilder = transactionBuilder
        self.network = network

        unspentOutputsNotificationToken = unspentOutputRealmResults.observe { [weak self] changeset in
            self?.handleUnspentOutputs(changeset: changeset)
        }

        transactionsNotificationToken = transactionRealmResults.observe { [weak self] changeset in
            self?.handleTransactions(changeset: changeset)
        }

        blocksNotificationToken = blockRealmResults.observe { [weak self] changeset in
            self?.handleBlocks(changeset: changeset)
        }
    }

    deinit {
        unspentOutputsNotificationToken?.invalidate()
        transactionsNotificationToken?.invalidate()
        blocksNotificationToken?.invalidate()
    }

    private func handleTransactions(changeset: RealmCollectionChange<Results<Transaction>>) {
        if case let .update(collection, deletions, insertions, modifications) = changeset {
            delegate?.transactionsUpdated(
                    inserted: insertions.map { collection[$0] }.map { transactionInfo(fromTransaction: $0) },
                    updated: modifications.map { collection[$0] }.map { transactionInfo(fromTransaction: $0) },
                    deleted: deletions
            )
        }
    }

    private func handleBlocks(changeset: RealmCollectionChange<Results<Block>>) {
        if case let .update(collection, deletions, insertions, _) = changeset, let block = collection.last, (!deletions.isEmpty || !insertions.isEmpty) {
            delegate?.lastBlockInfoUpdated(lastBlockInfo: blockInfo(fromBlock: block))
            handleProgressUpdate(block: block)
        }
    }

    private func handleUnspentOutputs(changeset: RealmCollectionChange<Results<TransactionOutput>>) {
        if case .update = changeset {
            delegate?.balanceUpdated(balance: balance)
        }
    }

    private func handleProgressUpdate(block: Block) {
        let progress: Double!

        if knownBestBlockHeight == 0 {
            progress = 0
        } else {
            if knownBestBlockHeight < block.height {
                knownBestBlockHeight = block.height
            }

            progress = knownBestBlockHeight == network.checkpointBlock.height
                    ? 1
                    : Double(block.height - network.checkpointBlock.height) / Double(knownBestBlockHeight - network.checkpointBlock.height)
        }

        delegate?.progressUpdated(progress: progress)
    }

    private var unspentOutputRealmResults: Results<TransactionOutput> {
        return realmFactory.realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType != %@", ScriptType.unknown.rawValue)
                .filter("inputs.@count = %@", 0)
    }

    private var transactionRealmResults: Results<Transaction> {
        return realmFactory.realm.objects(Transaction.self).filter("isMine = %@", true).sorted(byKeyPath: "block.height", ascending: false)
    }

    private var blockRealmResults: Results<Block> {
        return realmFactory.realm.objects(Block.self).sorted(byKeyPath: "height")
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
                timestamp: transaction.block?.header?.timestamp
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

extension DataProvider: IDataProvider {

    var transactions: [TransactionInfo] {
        return transactionRealmResults.map { transactionInfo(fromTransaction: $0) }
    }

    var lastBlockInfo: BlockInfo? {
        return blockRealmResults.last.map { blockInfo(fromBlock: $0) }
    }

    var balance: Int {
        var balance = 0

        for output in unspentOutputRealmResults {
            balance += output.value
        }

        return balance
    }

    func send(to address: String, value: Int) throws {
        try transactionCreator.create(to: address, value: value)
    }

    func validate(address: String) throws {
        _ = try addressConverter.convert(address: address)
    }

    func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try transactionBuilder.fee(for: value, feeRate: transactionCreator.feeRate, senderPay: true, address: toAddress)
    }

    var receiveAddress: String {
        return (try? addressManager.receiveAddress()) ?? ""
    }

    var debugInfo: String {
        var lines = [String]()

        let realm = realmFactory.realm

        let blocks = realm.objects(Block.self).sorted(byKeyPath: "height")
        let syncedBlocks = blocks
        let pubKeys = realm.objects(PublicKey.self)

        for pubKey in pubKeys {
            let scriptType: ScriptType = (network is BitcoinCashMainNet || network is BitcoinCashTestNet) ? .p2pkh : .p2wpkh
            let bechAddress = (try? addressConverter.convert(keyHash: OpCode.scriptWPKH(pubKey.keyHash), type: scriptType).stringValue) ?? "none"
            lines.append("\(pubKey.index) --- \(pubKey.external) --- hash: \(pubKey.keyHash.hex) --- p2wkph(SH) hash: \(pubKey.scriptHashForP2WPKH.hex)")
            lines.append("legacy: \(addressConverter.convertToLegacy(keyHash: pubKey.keyHash, version: network.pubKeyHash, addressType: .pubKeyHash).stringValue) --- bech32: \(bechAddress) --- SH(WPKH): \(addressConverter.convertToLegacy(keyHash: pubKey.scriptHashForP2WPKH, version: network.scriptHash, addressType: .scriptHash).stringValue) \n")
        }
        lines.append("PUBLIC KEYS COUNT: \(pubKeys.count)")

        lines.append("BLOCK COUNT: \(blocks.count) --- \(syncedBlocks.count) synced")
        if let block = syncedBlocks.first {
            lines.append("First Synced Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }
        if let block = syncedBlocks.last {
            lines.append("Last Synced Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }

        return lines.joined(separator: "\n")
    }

}

extension DataProvider: BestBlockHeightDelegate {

    func bestBlockHeightReceived(height: Int32) {
        if height > knownBestBlockHeight {
            knownBestBlockHeight = Int(height)
            if let lastBlock = blockRealmResults.last {
                handleProgressUpdate(block: lastBlock)
            }
        }
    }

}

protocol DataProviderDelegate: class {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int])
    func balanceUpdated(balance: Int)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
    func progressUpdated(progress: Double)
}
