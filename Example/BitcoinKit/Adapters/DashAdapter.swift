import DashKit
import BitcoinCore
import HsToolKit
import DashKit
import RxSwift

class DashAdapter: BaseAdapter {
    override var feeRate: Int { return 1 }
    private let dashKit: Kit

    init(words: [String], testMode: Bool, syncMode: BitcoinCore.SyncMode, logger: Logger) {
        let networkType: Kit.NetworkType = testMode ? .testNet : .mainNet
        dashKit = try! Kit(withWords: words, walletId: "walletId", syncMode: syncMode, networkType: networkType, logger: logger.scoped(with: "DashKit"))

        super.init(name: "Dash", coinCode: "DASH", abstractKit: dashKit)
        dashKit.delegate = self
    }

    override func transactionsSingle(fromUid: String?, limit: Int) -> Single<[TransactionRecord]> {
        dashKit.transactions(fromUid: fromUid, limit: limit)
                .map { [weak self] transactions -> [TransactionRecord] in
                    transactions.compactMap {
                        self?.transactionRecord(fromTransaction: $0)
                    }
                }
    }

    private func transactionRecord(fromTransaction transaction: DashTransactionInfo) -> TransactionRecord {
        var record = transactionRecord(fromTransaction: transaction as TransactionInfo)
        if transaction.instantTx {
            record.transactionExtraType = "Instant"
        }

        return record
    }

    class func clear() {
        try? Kit.clear()
    }
}

extension DashAdapter: DashKitDelegate {

    public func transactionsUpdated(inserted: [DashTransactionInfo], updated: [DashTransactionInfo]) {
        transactionsSignal.notify()
    }

    func transactionsDeleted(hashes: [String]) {
        transactionsSignal.notify()
    }

    func balanceUpdated(balance: BalanceInfo) {
        balanceSignal.notify()
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        syncStateSignal.notify()
    }

}
