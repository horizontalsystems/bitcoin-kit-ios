class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
    }

    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let transactionSender: ITransactionSender
    private let bloomFilterManager: IBloomFilterManager

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, transactionSender: ITransactionSender, bloomFilterManager: IBloomFilterManager) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.transactionSender = transactionSender
        self.bloomFilterManager = bloomFilterManager
    }

    private func processAndSend(transaction: FullTransaction) throws {
        try transactionSender.verifyCanSend()

        do {
            try transactionProcessor.processCreated(transaction: transaction)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            bloomFilterManager.regenerateBloomFilter()
        }

        try transactionSender.send(pendingTransaction: transaction)
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool, pluginData: [UInt8: IPluginData] = [:]) throws -> FullTransaction {
        let transaction = try transactionBuilder.buildTransaction(
                toAddress: address,
                value: value,
                feeRate: feeRate,
                senderPay: senderPay,
                pluginData: pluginData
        )

        try processAndSend(transaction: transaction)
        return transaction
    }

    func create(from unspentOutput: UnspentOutput, to address: String, feeRate: Int) throws -> FullTransaction {
        let transaction = try transactionBuilder.buildTransaction(from: unspentOutput, toAddress: address, feeRate: feeRate)

        try processAndSend(transaction: transaction)
        return transaction
    }

}
