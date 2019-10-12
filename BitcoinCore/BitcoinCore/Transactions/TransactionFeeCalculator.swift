class TransactionFeeCalculator {

    private let unspentOutputSelector: IUnspentOutputSelector
    private let transactionSizeCalculator: ITransactionSizeCalculator
    private let outputSetter: OutputSetter
    private let inputSetter: InputSetter
    private let addressConverter: IAddressConverter
    private let publicKeyManager: IPublicKeyManager
    private let changeScriptType: ScriptType

    init(unspentOutputSelector: IUnspentOutputSelector, transactionSizeCalculator: ITransactionSizeCalculator, outputSetter: OutputSetter, inputSetter: InputSetter,
         addressConverter: IAddressConverter, publicKeyManager: IPublicKeyManager, changeScriptType: ScriptType) {
        self.unspentOutputSelector = unspentOutputSelector
        self.transactionSizeCalculator = transactionSizeCalculator
        self.outputSetter = outputSetter
        self.inputSetter = inputSetter
        self.addressConverter = addressConverter
        self.publicKeyManager = publicKeyManager
        self.changeScriptType = changeScriptType
    }

    private func sampleAddress() throws -> String {
        try addressConverter.convert(publicKey: try publicKeyManager.changePublicKey(), type: changeScriptType).stringValue
    }
}

extension TransactionFeeCalculator: ITransactionFeeCalculator {

    func fee(for value: Int, feeRate: Int, senderPay: Bool, toAddress: String?, pluginData: [String: [String: Any]] = [:]) throws -> Int {
        let mutableTransaction = MutableTransaction()

        try outputSetter.setOutputs(to: mutableTransaction, toAddress: toAddress ?? (try sampleAddress()), value: value, pluginData: pluginData)
        try inputSetter.setInputs(to: mutableTransaction, feeRate: feeRate, senderPay: senderPay)

        let inputsTotalValue = mutableTransaction.inputsToSign.reduce(0) { total, input in total + input.previousOutput.value }
        let outputsTotalValue = mutableTransaction.recipientValue + mutableTransaction.changeValue

        return inputsTotalValue - outputsTotalValue
    }

    func fee(inputScriptType: ScriptType, outputScriptType: ScriptType, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) -> Int {
        let emptySignature = Data(repeating: 0, count: TransactionSizeCalculator.signatureLength)
        let emptyPublicKey = Data(repeating: 0, count: TransactionSizeCalculator.pubKeyLength)

        let transactionSize = transactionSizeCalculator.transactionSize(inputs: [inputScriptType], outputScriptTypes: [outputScriptType], pluginDataOutputSize: 0) +
                signatureScriptFunction(emptySignature, emptyPublicKey).count

        return transactionSize * feeRate
    }

}
