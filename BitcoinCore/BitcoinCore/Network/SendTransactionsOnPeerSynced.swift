import Foundation

class SendTransactionsOnPeerSynced: IPeerSyncListener {
    private var transactionSender: ITransactionSender?

    init(transactionSender: ITransactionSender?) {
        self.transactionSender = transactionSender
    }

    func onAllPeersSynced() {
        transactionSender?.sendPendingTransactions()
    }

}
