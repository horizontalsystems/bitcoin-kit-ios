import DashKit
import BitcoinCore
import DashKit
import RxSwift

class DashAdapter: BaseAdapter {
    override var feeRate: Int { return 1 }
    private let dashKit: DashKit

    init(words: [String], testMode: Bool, syncMode: BitcoinCore.SyncMode) {
        let networkType: DashKit.NetworkType = testMode ? .testNet : .mainNet
        dashKit = try! DashKit(withWords: words, walletId: "walletId", syncMode: syncMode, networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Dash", coinCode: "DASH", abstractKit: dashKit)
        dashKit.delegate = self
    }

    override func transactionsSingle(fromHash: String?, fromTimestamp: Int?, limit: Int) -> Single<[TransactionRecord]> {
        dashKit.transactions(fromHash: fromHash, fromTimestamp: fromTimestamp, limit: limit)
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
        try? DashKit.clear()
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
