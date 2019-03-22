class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
    }

    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let peerGroup: IPeerGroup

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, peerGroup: IPeerGroup) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.peerGroup = peerGroup
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool) throws {
        try peerGroup.checkPeersSynced()

        let transaction = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: senderPay, toAddress: address)

        try transactionProcessor.processCreated(transaction: transaction)
        try peerGroup.sendPendingTransactions()
    }

}
