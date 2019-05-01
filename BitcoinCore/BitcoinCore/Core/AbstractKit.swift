import Foundation
import RxSwift

open class AbstractKit {
    public var bitcoinCore: BitcoinCore
    public var network: INetwork

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            guard let delegate = delegate else {
                return
            }
            bitcoinCore.add(delegate: delegate)
        }
    }

    public init(bitcoinCore: BitcoinCore, network: INetwork) {
        self.bitcoinCore = bitcoinCore
        self.network = network
    }

    open func start() throws {
        try bitcoinCore.start()
    }

    open func stop() {
        bitcoinCore.stop()
    }

    open func clear() throws {
        try bitcoinCore.clear()
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

    open func send(to address: String, value: Int, feeRate: Int) throws {
        try bitcoinCore.send(to: address, value: value, feeRate: feeRate)
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

    open var receiveAddress: String {
        return bitcoinCore.receiveAddress
    }

    open var debugInfo: String {
        return bitcoinCore.debugInfo
    }

}