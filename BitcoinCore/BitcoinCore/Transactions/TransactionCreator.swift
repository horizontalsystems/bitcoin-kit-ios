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
    private let publicKeyManager: IPublicKeyManager
    private let storage: IStorage
    private let bip: Bip

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, transactionSender: ITransactionSender, transactionFeeCalculator: ITransactionFeeCalculator,
         bloomFilterManager: IBloomFilterManager, addressConverter: IAddressConverter, publicKeyManager: IPublicKeyManager, storage: IStorage, bip: Bip) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.transactionSender = transactionSender
        self.transactionFeeCalculator = transactionFeeCalculator
        self.bloomFilterManager = bloomFilterManager
        self.addressConverter = addressConverter
        self.publicKeyManager = publicKeyManager
        self.storage = storage
        self.bip = bip
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

    private func create(to toAddress: Address, value: Int, feeRate: Int, senderPay: Bool) throws -> FullTransaction {
        let feeWithUnspentOutputs = try transactionFeeCalculator.feeWithUnspentOutputs(value: value, feeRate: feeRate, toScriptType: toAddress.scriptType, changeScriptType: bip.scriptType, senderPay: senderPay)

        var changeAddress: Address? = nil
        if feeWithUnspentOutputs.addChangeOutput {
            let changePubKey = try publicKeyManager.changePublicKey()
            changeAddress = try addressConverter.convert(publicKey: changePubKey, type: bip.scriptType)
        }

        let transaction = try transactionBuilder.buildTransaction(
                value: value, unspentOutputs: feeWithUnspentOutputs.unspentOutputs, fee: feeWithUnspentOutputs.fee, senderPay: senderPay,
                toAddress: toAddress, changeAddress: changeAddress, lastBlockHeight: storage.lastBlock?.height ?? 0
        )

        try processAndSend(transaction: transaction)
        return transaction
    }

}

extension TransactionCreator: ITransactionCreator {

    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool) throws -> FullTransaction {
        let toAddress = try addressConverter.convert(address: address)
        return try create(to: toAddress, value: value, feeRate: feeRate, senderPay: senderPay)
    }

    func create(to hash: Data, scriptType: ScriptType, value: Int, feeRate: Int, senderPay: Bool) throws -> FullTransaction {
        let toAddress = try addressConverter.convert(keyHash: hash, type: scriptType)
        return try create(to: toAddress, value: value, feeRate: feeRate, senderPay: senderPay)
    }

    func create(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        let toAddress = try addressConverter.convert(address: address)
        let fee = transactionFeeCalculator.fee(inputScriptType: unspentOutput.output.scriptType, outputScriptType: toAddress.scriptType, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)
        let transaction = try transactionBuilder.buildTransaction(from: unspentOutput, to: toAddress, fee: fee, lastBlockHeight: storage.lastBlock?.height ?? 0, signatureScriptFunction: signatureScriptFunction)

        try processAndSend(transaction: transaction)
        return transaction
    }

}
