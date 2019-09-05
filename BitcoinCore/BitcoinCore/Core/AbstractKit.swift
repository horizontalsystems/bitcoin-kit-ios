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
        return bitcoinCore.lastBlockInfo
    }

    open var balance: Int {
        return bitcoinCore.balance
    }

    open var syncState: BitcoinCore.KitState {
        return bitcoinCore.syncState
    }

    open func transactions(fromHash: String? = nil, limit: Int? = nil) -> Single<[TransactionInfo]> {
        return bitcoinCore.transactions(fromHash: fromHash, limit: limit)
    }

    open func send(to address: String, value: Int, feeRate: Int) throws -> FullTransaction {
        return try bitcoinCore.send(to: address, value: value, feeRate: feeRate)
    }

    public func send(to hash: Data, scriptType: ScriptType, value: Int, feeRate: Int) throws -> FullTransaction {
        return try bitcoinCore.send(to: hash, scriptType: scriptType, value: value, feeRate: feeRate)
    }

    public func redeem(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        return try bitcoinCore.redeem(from: unspentOutput, to: address, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
    }

    open func validate(address: String) throws {
        try bitcoinCore.validate(address: address)
    }

    open func parse(paymentAddress: String) -> BitcoinPaymentData {
        return bitcoinCore.parse(paymentAddress: paymentAddress)
    }

    open func fee(for value: Int, toAddress: String? = nil, senderPay: Bool, feeRate: Int) throws -> Int {
        return try bitcoinCore.fee(for: value, toAddress: toAddress, senderPay: senderPay, feeRate: feeRate)
    }

    open func receiveAddress() -> String {
        return bitcoinCore.receiveAddress()
    }

    open func changePublicKey() throws -> PublicKey {
        return try bitcoinCore.changePublicKey()
    }

    open func receivePublicKey() throws -> PublicKey {
        return try bitcoinCore.receivePublicKey()
    }

    public func publicKey(byPath path: String) throws -> PublicKey {
        return try bitcoinCore.publicKey(byPath: path)
    }

    open func watch(transaction: BitcoinCore.TransactionFilter, delegate: IWatchedTransactionDelegate) {
        bitcoinCore.watch(transaction: transaction, delegate: delegate)
    }

    open var debugInfo: String {
        return bitcoinCore.debugInfo
    }

}
