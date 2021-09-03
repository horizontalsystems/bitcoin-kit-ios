import Foundation
import RxSwift

open class AbstractKit {
    public var bitcoinCore: BitcoinCore
    public var network: INetwork

    public init(bitcoinCore: BitcoinCore, network: INetwork) {
        self.bitcoinCore = bitcoinCore
        self.network = network
    }

    open func start() {
        bitcoinCore.start()
    }

    open func stop() {
        bitcoinCore.stop()
    }

    open var lastBlockInfo: BlockInfo? {
        bitcoinCore.lastBlockInfo
    }

    open var balance: BalanceInfo {
        bitcoinCore.balance
    }

    open var syncState: BitcoinCore.KitState {
        bitcoinCore.syncState
    }

    open func transactions(fromUid: String? = nil, type: TransactionFilterType?, limit: Int? = nil) -> Single<[TransactionInfo]> {
        bitcoinCore.transactions(fromUid: fromUid, type: type, limit: limit)
    }

    open func transaction(hash: String) -> TransactionInfo? {
        bitcoinCore.transaction(hash: hash)
    }

    open func send(to address: String, value: Int, feeRate: Int, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData] = [:]) throws -> FullTransaction {
        try bitcoinCore.send(to: address, value: value, feeRate: feeRate, sortType: sortType, pluginData: pluginData)
    }

    public func send(to hash: Data, scriptType: ScriptType, value: Int, feeRate: Int, sortType: TransactionDataSortType) throws -> FullTransaction {
        try bitcoinCore.send(to: hash, scriptType: scriptType, value: value, feeRate: feeRate, sortType: sortType)
    }

    public func redeem(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, sortType: TransactionDataSortType) throws -> FullTransaction {
        try bitcoinCore.redeem(from: unspentOutput, to: address, feeRate: feeRate, sortType: sortType)
    }

    open func createRawTransaction(to address: String, value: Int, feeRate: Int, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData] = [:]) throws -> Data {
        try bitcoinCore.createRawTransaction(to: address, value: value, feeRate: feeRate, sortType: sortType, pluginData: pluginData)
    }

    open func validate(address: String, pluginData: [UInt8: IPluginData] = [:]) throws {
        try bitcoinCore.validate(address: address, pluginData: pluginData)
    }

    open func parse(paymentAddress: String) -> BitcoinPaymentData {
        bitcoinCore.parse(paymentAddress: paymentAddress)
    }

    open func fee(for value: Int, toAddress: String? = nil, feeRate: Int, pluginData: [UInt8: IPluginData] = [:]) throws -> Int {
        try bitcoinCore.fee(for: value, toAddress: toAddress, feeRate: feeRate, pluginData: pluginData)
    }

    open func maxSpendableValue(toAddress: String? = nil, feeRate: Int, pluginData: [UInt8: IPluginData] = [:]) throws -> Int {
        try bitcoinCore.maxSpendableValue(toAddress: toAddress, feeRate: feeRate, pluginData: pluginData)
    }

    open func maxSpendLimit(pluginData: [UInt8: IPluginData]) throws -> Int? {
        try bitcoinCore.maxSpendLimit(pluginData: pluginData)
    }

    open func minSpendableValue(toAddress: String? = nil) -> Int {
        bitcoinCore.minSpendableValue(toAddress: toAddress)
    }

    open func receiveAddress() -> String {
        bitcoinCore.receiveAddress()
    }

    open func changePublicKey() throws -> PublicKey {
        try bitcoinCore.changePublicKey()
    }

    open func receivePublicKey() throws -> PublicKey {
        try bitcoinCore.receivePublicKey()
    }

    public func publicKey(byPath path: String) throws -> PublicKey {
        try bitcoinCore.publicKey(byPath: path)
    }

    open func watch(transaction: BitcoinCore.TransactionFilter, delegate: IWatchedTransactionDelegate) {
        bitcoinCore.watch(transaction: transaction, delegate: delegate)
    }

    open var debugInfo: String {
        bitcoinCore.debugInfo(network: network)
    }

    open var statusInfo: [(String, Any)] {
        bitcoinCore.statusInfo
    }

    public func rawTransaction(transactionHash: String) -> String? {
        bitcoinCore.rawTransaction(transactionHash: transactionHash)
    }

}
