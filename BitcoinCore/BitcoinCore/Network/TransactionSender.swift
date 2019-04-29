class TransactionSender: ITransactionSender {
    var transactionSyncer: ITransactionSyncer?
    var peerGroup: IPeerGroup?
    var logger: Logger?

    init(transactionSyncer: ITransactionSyncer? = nil, peerGroup: IPeerGroup? = nil, logger: Logger? = nil) {
        self.transactionSyncer = transactionSyncer
        self.peerGroup = peerGroup
        self.logger = logger
    }

    func sendPendingTransactions() {
        do {
            try canSendTransaction()

            peerGroup?.someReadyPeers.forEach { peer in
                transactionSyncer?.pendingTransactions().forEach { transaction in
                    peer.add(task: SendTransactionTask(transaction: transaction))
                }
            }
        } catch {
            self.logger?.error(error.localizedDescription)
        }
    }

    func canSendTransaction() throws {
        try peerGroup?.checkPeersSynced()
    }

}
