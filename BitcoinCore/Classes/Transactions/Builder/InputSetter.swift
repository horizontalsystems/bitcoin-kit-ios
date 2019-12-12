class InputSetter {
    enum UnspentOutputError: Error {
        case feeMoreThanValue
        case notSupportedScriptType
    }

    private let unspentOutputSelector: IUnspentOutputSelector
    private let transactionSizeCalculator: ITransactionSizeCalculator
    private let addressConverter: IAddressConverter
    private let publicKeyManager: IPublicKeyManager
    private let factory: IFactory
    private let pluginManager: IPluginManager
    private let dustCalculator: IDustCalculator
    private let changeScriptType: ScriptType

    init(unspentOutputSelector: IUnspentOutputSelector, transactionSizeCalculator: ITransactionSizeCalculator, addressConverter: IAddressConverter, publicKeyManager: IPublicKeyManager,
         factory: IFactory, pluginManager: IPluginManager, dustCalculator: IDustCalculator, changeScriptType: ScriptType) {
        self.unspentOutputSelector = unspentOutputSelector
        self.transactionSizeCalculator = transactionSizeCalculator
        self.addressConverter = addressConverter
        self.publicKeyManager = publicKeyManager
        self.factory = factory
        self.pluginManager = pluginManager
        self.dustCalculator = dustCalculator
        self.changeScriptType = changeScriptType
    }

    private func input(fromUnspentOutput unspentOutput: UnspentOutput) throws -> InputToSign {
        if unspentOutput.output.scriptType == .p2wpkh {
            // todo: refactoring version byte!
            // witness key hashes stored with program byte and push code to determine
            // version (current only 0), but for sign we need only public kee hash
            unspentOutput.output.keyHash?.removeFirst(2)
        }

        // Maximum nSequence value (0xFFFFFFFF) disables nLockTime.
        // According to BIP-125, any value less than 0xFFFFFFFE makes a Replace-by-Fee(RBF) opted in.
        let sequence = 0xFFFFFFFE

        return factory.inputToSign(withPreviousOutput: unspentOutput, script: Data(), sequence: sequence)
    }

}

extension InputSetter: IInputSetter {

    func setInputs(to mutableTransaction: MutableTransaction, feeRate: Int, senderPay: Bool) throws {
        let value = mutableTransaction.recipientValue
        let dust = dustCalculator.dust(type: changeScriptType)
        let unspentOutputInfo = try unspentOutputSelector.select(
                value: value, feeRate: feeRate,
                outputScriptType: mutableTransaction.recipientAddress.scriptType, changeType: changeScriptType,
                senderPay: senderPay, dust: dust, pluginDataOutputSize: mutableTransaction.pluginDataOutputSize
        )
        let unspentOutputs = unspentOutputInfo.unspentOutputs

        for unspentOutput in unspentOutputs {
            mutableTransaction.add(inputToSign: try input(fromUnspentOutput: unspentOutput))
        }

        mutableTransaction.recipientValue = unspentOutputInfo.recipientValue

        // Add change output if needed
        if let changeValue = unspentOutputInfo.changeValue {
            let changePubKey = try publicKeyManager.changePublicKey()
            let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: changeScriptType)

            mutableTransaction.changeAddress = changeAddress
            mutableTransaction.changeValue = changeValue
        }

        try pluginManager.processInputs(mutableTransaction: mutableTransaction)
    }

    func setInputs(to mutableTransaction: MutableTransaction, fromUnspentOutput unspentOutput: UnspentOutput, feeRate: Int) throws {
        guard unspentOutput.output.scriptType == .p2sh else {
            throw UnspentOutputError.notSupportedScriptType
        }

        // Calculate fee
        let emptySignature = Data(repeating: 0, count: TransactionSizeCalculator.signatureLength)
        let emptyPublicKey = Data(repeating: 0, count: TransactionSizeCalculator.pubKeyLength)

        var transactionSize = transactionSizeCalculator.transactionSize(inputs: [unspentOutput.output.scriptType], outputScriptTypes: [mutableTransaction.recipientAddress.scriptType], pluginDataOutputSize: 0)
        if let signatureScriptFunction = unspentOutput.output.signatureScriptFunction {
            transactionSize += signatureScriptFunction([emptySignature, emptyPublicKey]).count
        }

        let fee = transactionSize * feeRate

        guard fee < unspentOutput.output.value else {
            throw UnspentOutputError.feeMoreThanValue
        }

        // Add to mutable transaction
        mutableTransaction.add(inputToSign: try input(fromUnspentOutput: unspentOutput))
        mutableTransaction.recipientValue = unspentOutput.output.value - fee
    }

}
