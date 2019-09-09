class TransactionCreator {
    enum CreationError: Error {
        case transactionAlreadyExists
    }

    private let transactionBuilder: ITransactionBuilder
    private let transactionProcessor: ITransactionProcessor
    private let transactionSender: ITransactionSender
    private let bloomFilterManager: IBloomFilterManager
    private let addressConverter: IAddressConverter
    private let publicKeyManager: IPublicKeyManager
    private let bip: Bip

    init(transactionBuilder: ITransactionBuilder, transactionProcessor: ITransactionProcessor, transactionSender: ITransactionSender, bloomFilterManager: IBloomFilterManager,
         addressConverter: IAddressConverter, publicKeyManager: IPublicKeyManager, bip: Bip) {
        self.transactionBuilder = transactionBuilder
        self.transactionProcessor = transactionProcessor
        self.transactionSender = transactionSender
        self.bloomFilterManager = bloomFilterManager
        self.addressConverter = addressConverter
        self.publicKeyManager = publicKeyManager
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
        let changePubKey = try publicKeyManager.changePublicKey()
        let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: bip.scriptType)

        let transaction = try transactionBuilder.buildTransaction(value: value, feeRate: feeRate, senderPay: senderPay, toAddress: toAddress, changeAddress: changeAddress)

        try processAndSend(transaction: transaction)
        return transaction
    }

}

extension TransactionCreator: ITransactionCreator {

    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String?) throws -> Int {
        let toAddress = try address.map { try addressConverter.convert(address: $0) }
        let changePubKey = try publicKeyManager.changePublicKey()
        let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: bip.scriptType)

        return try transactionBuilder.fee(for: value, feeRate: feeRate, senderPay: senderPay, toAddress: toAddress, changeAddress: changeAddress)
    }

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
        let transaction = try transactionBuilder.buildTransaction(from: unspentOutput, to: toAddress, feeRate: feeRate, signatureScriptFunction: signatureScriptFunction)

        try processAndSend(transaction: transaction)
        return transaction
    }

}
