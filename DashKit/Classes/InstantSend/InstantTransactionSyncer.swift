import BitcoinCore

class InstantTransactionSyncer: IDashTransactionSyncer {
    private let transactionSyncer: ITransactionSyncer

    init(transactionSyncer: ITransactionSyncer) {
        self.transactionSyncer = transactionSyncer
    }

    func handleRelayed(transactions: [FullTransaction]) {
        transactionSyncer.handleRelayed(transactions: transactions)
    }

}
