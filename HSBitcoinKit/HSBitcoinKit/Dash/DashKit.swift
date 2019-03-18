import Foundation
import HSHDWalletKit
import RealmSwift
import BigInt
import HSCryptoKit
import RxSwift

enum InventoryType: Int32 { case msgTxLockRequest = 4, msgTxLockVote = 5 }

public class DashKit {

    public weak var delegate: DashKitDelegate?
    private let bitcoinKit: BitcoinKit
    private let dashConfigurator: IBitCoreConfigurator
    private let masternodeSyncer: MasternodeListSyncer

    public init(withWords words: [String], coin: BitcoinKit.Coin, walletId: String, newWallet: Bool = true, confirmationsThreshold: Int = 6, minLogLevel: Logger.Level = .verbose) {
        bitcoinKit = BitcoinKit(withWords: words, coin: coin, walletId: walletId, newWallet: newWallet, confirmationsThreshold: confirmationsThreshold, minLogLevel: minLogLevel)

        let masternodeListManager = MasternodeListManager()
        masternodeSyncer = MasternodeListSyncer(peerGroup: bitcoinKit.peerGroup, peerTaskFactory: PeerTaskFactory(), masternodeListManager: masternodeListManager)
        dashConfigurator = DashConfigurator(transactionSyncer: bitcoinKit.transactionSyncer, masternodeSyncer: masternodeSyncer, bitCoreConfigurator: bitcoinKit.bitCoreConfigurator)
        bitcoinKit.delegate = self

        bitcoinKit.networkMessageParser = NetworkMessageParser(magic: bitcoinKit.network.magic, messageParsers: dashConfigurator.networkMessageParsers)
        bitcoinKit.peerGroup.peerTaskHandler = dashConfigurator.peerTaskHandler
        bitcoinKit.peerGroup.networkMessageParser = bitcoinKit.networkMessageParser
        bitcoinKit.peerGroup.inventoryItemsHandler = dashConfigurator.inventoryItemsHandler
    }

}

extension DashKit {

    public func start() throws {
        try bitcoinKit.start()
    }

    public func clear() throws {
        try bitcoinKit.clear()
    }

}

extension DashKit {

    public var lastBlockInfo: BlockInfo? {
        return bitcoinKit.lastBlockInfo
    }

    public var balance: Int {
        return bitcoinKit.balance
    }

    public var syncState: BitcoinKit.KitState {
        return bitcoinKit.syncState
    }

    public func transactions(fromHash: String? = nil, limit: Int? = nil) -> Single<[TransactionInfo]> {
        return bitcoinKit.transactions(fromHash: fromHash, limit: limit)
    }

    public func send(to address: String, value: Int) throws {
        try bitcoinKit.send(to: address, value: value)
    }

    public func validate(address: String) throws {
        try bitcoinKit.validate(address: address)
    }

    public func parse(paymentAddress: String) -> BitcoinPaymentData {
        return bitcoinKit.parse(paymentAddress: paymentAddress)
    }

    public func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try bitcoinKit.fee(for: value, toAddress: toAddress, senderPay: senderPay)
    }

    public var receiveAddress: String {
        return bitcoinKit.receiveAddress
    }

    public var debugInfo: String {
        return bitcoinKit.debugInfo
    }

}
extension DashKit: BitcoinKitDelegate {
    public func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo]) {
        self.delegate?.transactionsUpdated(BitcoinKit: bitcoinKit, inserted: inserted, updated: updated)
    }

    public func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int) {
        self.delegate?.balanceUpdated(BitcoinKit: bitcoinKit, balance: balance)
    }

    public func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo) {
        self.delegate?.lastBlockInfoUpdated(BitcoinKit: bitcoinKit, lastBlockInfo: lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinKit.KitState) {
        if (state == BitcoinKit.KitState.synced) {
            if let blockInfo = bitcoinKit.lastBlockInfo, let hash = blockInfo.headerHash.reversedData {
                masternodeSyncer.sync(blockHash: hash)
            }
        }

        self.delegate?.kitStateUpdated(state: state)
    }

    public func transactionsDeleted(hashes: [String]) {
        self.delegate?.transactionsDeleted(hashes: hashes)
    }
}

public protocol DashKitDelegate: class {
    func transactionsUpdated(BitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(BitcoinKit: BitcoinKit, balance: Int)
    func lastBlockInfoUpdated(BitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo)
    func kitStateUpdated(state: BitcoinKit.KitState)
}
