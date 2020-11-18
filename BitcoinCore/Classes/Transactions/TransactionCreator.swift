class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
        case noTransactionToRecreate
        case cannotRecreateConfirmedTransaction
    }

    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: IPendingTransactionProcessor
    private let transactionSender: ITransactionSender
    private let bloomFilterManager: IBloomFilterManager
    private let storage: IStorage

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: IPendingTransactionProcessor, transactionSender: ITransactionSender, bloomFilterManager: IBloomFilterManager, storage: IStorage) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.transactionSender = transactionSender
        self.bloomFilterManager = bloomFilterManager
        self.storage = storage
    }

    private func processAndSend(transaction: FullTransaction) throws {
        try transactionSender.verifyCanSend()

        do {
            try transactionProcessor.processCreated(transaction: transaction)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            bloomFilterManager.regenerateBloomFilter()
        }

        transactionSender.send(pendingTransaction: transaction)
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData] = [:]) throws -> FullTransaction {
        let transaction = try transactionBuilder.buildTransaction(
                toAddress: address,
                value: value,
                feeRate: feeRate,
                senderPay: senderPay,
                sortType: sortType,
                pluginData: pluginData
        )

        try processAndSend(transaction: transaction)
        return transaction
    }

    func create(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, sortType: TransactionDataSortType) throws -> FullTransaction {
        let transaction = try transactionBuilder.buildTransaction(from: unspentOutput, toAddress: address, feeRate: feeRate, sortType: sortType)

        try processAndSend(transaction: transaction)
        return transaction
    }

    func createRawTransaction(to address: String, value: Int, feeRate: Int, senderPay: Bool, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData] = [:]) throws -> Data {
        let transaction = try transactionBuilder.buildTransaction(
                toAddress: address,
                value: value,
                feeRate: feeRate,
                senderPay: senderPay,
                sortType: sortType,
                pluginData: pluginData
        )

        return TransactionSerializer.serialize(transaction: transaction)
    }

    public func recreate(transactionHash: String, feeRate: Int) throws -> FullTransaction {
        guard let dataHash = Data(hex: transactionHash), let existingTransaction = storage.fullTransaction(byHash: dataHash) else {
            throw CreationError.noTransactionToRecreate
        }

        guard existingTransaction.header.blockHash == nil else {
            throw CreationError.cannotRecreateConfirmedTransaction
        }

        let transaction = try transactionBuilder.rebuildTransaction(transaction: existingTransaction, feeRate: feeRate)

        try processAndSend(transaction: transaction)
        return transaction
    }

}
