import Foundation
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinCore {
    public static let heightInterval = 2016                                    // Default block count in difficulty change circle ( Bitcoin )
    public static let targetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. Bitcoin )
    public static let maxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks


    private let storage: IStorage
    private let cache: OutputsCache
    private var dataProvider: IDataProvider
    private let publicKeyManager: IPublicKeyManager
    private let watchedTransactionManager: IWatchedTransactionManager
    private let addressConverter: AddressConverterChain
    private let restoreKeyConverterChain: RestoreKeyConverterChain
    private let unspentOutputSelector: UnspentOutputSelectorChain
    private let kitStateProvider: IKitStateProvider & ISyncStateListener

    private let scriptBuilder: ScriptBuilderChain

    private let transactionCreator: ITransactionCreator
    private let transactionFeeCalculator: ITransactionFeeCalculator
    private let paymentAddressParser: IPaymentAddressParser

    private let networkMessageSerializer: NetworkMessageSerializer
    private let networkMessageParser: NetworkMessageParser

    private let syncManager: SyncManager

    private let bip: Bip

    // START: Extending

    public let peerGroup: IPeerGroup
    public let initialBlockDownload: IInitialBlockDownload
    public let syncedReadyPeerManager: ISyncedReadyPeerManager
    public let transactionSyncer: ITransactionSyncer

    let bloomFilterLoader: BloomFilterLoader
    let blockValidatorChain: BlockValidatorChain
    let inventoryItemsHandlerChain = InventoryItemsHandlerChain()
    let peerTaskHandlerChain = PeerTaskHandlerChain()

    public func add(blockValidator: IBlockValidator) {
        blockValidatorChain.add(blockValidator: blockValidator)
    }

    public func add(inventoryItemsHandler: IInventoryItemsHandler) {
        inventoryItemsHandlerChain.add(handler: inventoryItemsHandler)
    }

    public func add(peerTaskHandler: IPeerTaskHandler) {
        peerTaskHandlerChain.add(handler: peerTaskHandler)
    }

    public func add(restoreKeyConverterForBip bip: Bip) {
        restoreKeyConverterChain.add(converter: bip.restoreKeyConverter(addressConverter: addressConverter))
    }

    @discardableResult public func add(messageParser: IMessageParser) -> Self {
        networkMessageParser.add(parser: messageParser)
        return self
    }

    @discardableResult public func add(messageSerializer: IMessageSerializer) -> Self {
        networkMessageSerializer.add(serializer: messageSerializer)
        return self
    }

    func publicKey(byPath path: String) throws -> PublicKey {
        return try publicKeyManager.publicKey(byPath: path)
    }

    public func prepend(scriptBuilder: IScriptBuilder) {
        self.scriptBuilder.prepend(scriptBuilder: scriptBuilder)
    }

    public func prepend(addressConverter: IAddressConverter) {
        self.addressConverter.prepend(addressConverter: addressConverter)
    }

    public func prepend(unspentOutputSelector: IUnspentOutputSelector) {
        self.unspentOutputSelector.prepend(unspentOutputSelector: unspentOutputSelector)
    }

    // END: Extending

    public var delegateQueue = DispatchQueue(label: "bitcoin_delegate_queue")
    public weak var delegate: BitcoinCoreDelegate?

    init(storage: IStorage, cache: OutputsCache, dataProvider: IDataProvider,
         peerGroup: IPeerGroup, initialBlockDownload: IInitialBlockDownload, bloomFilterLoader: BloomFilterLoader,
         syncedReadyPeerManager: ISyncedReadyPeerManager, transactionSyncer: ITransactionSyncer,
         blockValidatorChain: BlockValidatorChain, publicKeyManager: IPublicKeyManager, addressConverter: AddressConverterChain, restoreKeyConverterChain: RestoreKeyConverterChain,
         unspentOutputSelector: UnspentOutputSelectorChain, kitStateProvider: IKitStateProvider & ISyncStateListener,
         scriptBuilder: ScriptBuilderChain, transactionCreator: ITransactionCreator, transactionFeeCalculator: ITransactionFeeCalculator,
         paymentAddressParser: IPaymentAddressParser, networkMessageParser: NetworkMessageParser, networkMessageSerializer: NetworkMessageSerializer,
         syncManager: SyncManager, watchedTransactionManager: IWatchedTransactionManager, bip: Bip) {
        self.storage = storage
        self.cache = cache
        self.dataProvider = dataProvider
        self.peerGroup = peerGroup
        self.initialBlockDownload = initialBlockDownload
        self.bloomFilterLoader = bloomFilterLoader
        self.syncedReadyPeerManager = syncedReadyPeerManager
        self.transactionSyncer = transactionSyncer
        self.blockValidatorChain = blockValidatorChain
        self.publicKeyManager = publicKeyManager
        self.addressConverter = addressConverter
        self.restoreKeyConverterChain = restoreKeyConverterChain
        self.unspentOutputSelector = unspentOutputSelector
        self.kitStateProvider = kitStateProvider
        self.scriptBuilder = scriptBuilder
        self.transactionCreator = transactionCreator
        self.transactionFeeCalculator = transactionFeeCalculator
        self.paymentAddressParser = paymentAddressParser

        self.networkMessageParser = networkMessageParser
        self.networkMessageSerializer = networkMessageSerializer

        self.syncManager = syncManager
        self.watchedTransactionManager = watchedTransactionManager
        self.bip = bip
    }

}

extension BitcoinCore {

    public func start() {
        syncManager.start()
    }

    func stop() {
        syncManager.stop()
    }

}

extension BitcoinCore {

    public var lastBlockInfo: BlockInfo? {
        return dataProvider.lastBlockInfo
    }

    public var balance: Int {
        return dataProvider.balance
    }

    public var syncState: BitcoinCore.KitState {
        return kitStateProvider.syncState
    }

    public func transactions(fromHash: String? = nil, limit: Int? = nil) -> Single<[TransactionInfo]> {
        return dataProvider.transactions(fromHash: fromHash, limit: limit)
    }

    public func send(to address: String, value: Int, feeRate: Int) throws -> FullTransaction {
        return try transactionCreator.create(to: address, value: value, feeRate: feeRate, senderPay: true)
    }

    public func send(to hash: Data, scriptType: ScriptType, value: Int, feeRate: Int) throws -> FullTransaction {
        return try transactionCreator.create(to: hash, scriptType: scriptType, value: value, feeRate: feeRate, senderPay: true)
    }

    func redeem(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        return try transactionCreator.create(from: unspentOutput, to: address, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
    }

    public func validate(address: String) throws {
        _ = try addressConverter.convert(address: address)
    }

    public func parse(paymentAddress: String) -> BitcoinPaymentData {
        return paymentAddressParser.parse(paymentAddress: paymentAddress)
    }

    public func fee(for value: Int, toAddress: String? = nil, senderPay: Bool, feeRate: Int) throws -> Int {
        let toAddress = try toAddress.map { try addressConverter.convert(address: $0) }
        let changePubKey = try publicKeyManager.changePublicKey()
        let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: bip.scriptType)

        return try transactionFeeCalculator.fee(for: value, feeRate: feeRate, senderPay: senderPay, toAddress: toAddress, changeAddress: changeAddress)
    }

    public func receiveAddress() -> String {
        guard let publicKey = try? publicKeyManager.receivePublicKey(),
              let address = try? addressConverter.convert(publicKey: publicKey, type: bip.scriptType) else {
            return ""
        }

        return address.stringValue
    }

    public func changePublicKey() throws -> PublicKey {
        return try publicKeyManager.changePublicKey()
    }

    public func receivePublicKey() throws -> PublicKey {
        return try publicKeyManager.receivePublicKey()
    }

    func watch(transaction: BitcoinCore.TransactionFilter, delegate: IWatchedTransactionDelegate) {
        watchedTransactionManager.add(transactionFilter: transaction, delegatedTo: delegate)
    }

    public var debugInfo: String {
        return dataProvider.debugInfo
    }

}

extension BitcoinCore: IDataProviderDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.transactionsUpdated(inserted: inserted, updated: updated)
            }
        }
    }

    func transactionsDeleted(hashes: [String]) {
        delegateQueue.async { [weak self] in
            self?.delegate?.transactionsDeleted(hashes: hashes)
        }
    }

    func balanceUpdated(balance: Int) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.balanceUpdated(balance: balance)
            }
        }
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.lastBlockInfoUpdated(lastBlockInfo: lastBlockInfo)
            }
        }
    }

}

extension BitcoinCore: IKitStateProviderDelegate {
    func handleKitStateUpdate(state: KitState) {
        delegateQueue.async { [weak self] in
            self?.delegate?.kitStateUpdated(state: state)
        }
    }
}

public protocol BitcoinCoreDelegate: class {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: Int)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
    func kitStateUpdated(state: BitcoinCore.KitState)
}

extension BitcoinCoreDelegate {

    public func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {}
    public func transactionsDeleted(hashes: [String]) {}
    public func balanceUpdated(balance: Int) {}
    public func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {}
    public func kitStateUpdated(state: BitcoinCore.KitState) {}

}

extension BitcoinCore {

    public enum KitState {
        case synced
        case syncing(progress: Double)
        case notSynced
    }

    public enum SyncMode: Equatable {
        case full                           // Sync from bip44CheckpointBlock. Api restore disabled
        case fromDate(date: TimeInterval)   // Sync from given date. Api restore disable
        case api                            // Sync from lastCheckpointBlock. Api restore enabled
        case newWallet                      // Sync from lastCheckpointBlock. Api restore enabled
    }

    public enum TransactionFilter {
        case p2shOutput(scriptHash: Data)
        case outpoint(transactionHash: Data, outputIndex: Int)
    }

}

extension BitcoinCore.KitState {

    public static func == (lhs: BitcoinCore.KitState, rhs: BitcoinCore.KitState) -> Bool {
        switch (lhs, rhs) {
        case (.synced, .synced), (.notSynced, .notSynced):
            return true
        case (.syncing(progress: let leftProgress), .syncing(progress: let rightProgress)):
            return leftProgress == rightProgress
        default:
            return false
        }
    }

}