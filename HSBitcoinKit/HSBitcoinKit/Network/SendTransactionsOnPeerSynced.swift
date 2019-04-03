import Foundation

class SendTransactionsOnPeerSynced: IAllPeersSyncedDelegate {
    private var transactionSender: ITransactionSender?

    init(transactionSender: ITransactionSender?) {
        self.transactionSender = transactionSender
    }

    func onAllPeersSynced() {
        transactionSender?.sendPendingTransactions()
    }

}
