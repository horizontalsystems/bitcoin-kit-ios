class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
    }

    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let transactionSender: ITransactionSender
    private let transactionFeeCalculator: ITransactionFeeCalculator
    private let bloomFilterManager: IBloomFilterManager
    private let addressConverter: IAddressConverter
    private let storage: IStorage

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, transactionSender: ITransactionSender, transactionFeeCalculator: ITransactionFeeCalculator,
         bloomFilterManager: IBloomFilterManager, addressConverter: IAddressConverter, storage: IStorage) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.transactionSender = transactionSender
        self.transactionFeeCalculator = transactionFeeCalculator
        self.bloomFilterManager = bloomFilterManager
        self.addressConverter = addressConverter
        self.storage = storage
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

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool, extraData: [String: [String: Any]] = [:]) throws -> FullTransaction {
        let transaction = try transactionBuilder.buildTransaction(
                toAddress: address,
                value: value,
                feeRate: feeRate,
                senderPay: senderPay,
                extraData: extraData
        )

        try processAndSend(transaction: transaction)
        return transaction
    }

    func create(to hash: Data, scriptType: ScriptType, value: Int, feeRate: Int, senderPay: Bool) throws -> FullTransaction {
        let toAddress = try addressConverter.convert(keyHash: hash, type: scriptType)
        return try create(to: toAddress.stringValue, value: value, feeRate: feeRate, senderPay: senderPay)
    }

    func create(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        let toAddress = try addressConverter.convert(address: address)
        let fee = transactionFeeCalculator.fee(inputScriptType: unspentOutput.output.scriptType, outputScriptType: toAddress.scriptType, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
        let transaction = try transactionBuilder.buildTransaction(from: unspentOutput, to: toAddress, fee: fee, lastBlockHeight: storage.lastBlock?.height ?? 0, signatureScriptFunction: signatureScriptFunction)

        try processAndSend(transaction: transaction)
        return transaction
    }

}
