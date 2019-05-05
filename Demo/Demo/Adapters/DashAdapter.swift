import DashKit
import BitcoinCore
import DashKit
import RxSwift

class DashAdapter: BaseAdapter {
    private let dashKit: DashKit

    init(words: [String], testMode: Bool) {
        let networkType: DashKit.NetworkType = testMode ? .testNet : .mainNet
        dashKit = try! DashKit(withWords: words, walletId: "walletId", newWallet: true, networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Dash", coinCode: "DASH", abstractKit: dashKit)
        dashKit.delegate = self
    }

    override func transactionsSingle(fromHash: String?, limit: Int) -> Single<[TransactionRecord]> {
        return dashKit.transactions(fromHash: fromHash, limit: limit)
                .map { [weak self] transactions -> [TransactionRecord] in
                    return transactions.compactMap {
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

}

extension DashAdapter: DashKitDelegate {

    public func transactionsUpdated(inserted: [DashTransactionInfo], updated: [DashTransactionInfo]) {
        transactionsSignal.notify()
    }

    func transactionsDeleted(hashes: [String]) {
        transactionsSignal.notify()
    }

    func balanceUpdated(balance: Int) {
        balanceSignal.notify()
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        syncStateSignal.notify()
    }

}
