import BitcoinCore

class InstantTransactionSyncer: IDashTransactionSyncer {
    private let transactionSyncer: ITransactionSyncer

    init(transactionSyncer: ITransactionSyncer) {
        self.transactionSyncer = transactionSyncer
    }

    func handle(transactions: [FullTransaction]) {
        transactionSyncer.handle(transactions: transactions)
    }

}
