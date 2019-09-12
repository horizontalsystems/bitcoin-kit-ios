class TransactionFeeCalculator {

    private let unspentOutputSelector: IUnspentOutputSelector
    private let transactionSizeCalculator: ITransactionSizeCalculator

    init(unspentOutputSelector: IUnspentOutputSelector, transactionSizeCalculator: ITransactionSizeCalculator) {
        self.unspentOutputSelector = unspentOutputSelector
        self.transactionSizeCalculator = transactionSizeCalculator
    }

}

extension TransactionFeeCalculator: ITransactionFeeCalculator {

    func fee(for value: Int, feeRate: Int, senderPay: Bool, toAddress: Address?, changeAddress: Address) throws -> Int {
        var outputScriptType = changeAddress.scriptType
        if let address = toAddress {
            outputScriptType = address.scriptType
        }

        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: outputScriptType, changeType: changeAddress.scriptType, senderPay: senderPay)
        return selectedOutputsInfo.fee
    }

    func feeWithUnspentOutputs(value: Int, feeRate: Int, toScriptType: ScriptType, changeScriptType: ScriptType, senderPay: Bool) throws -> SelectedUnspentOutputInfo {
        return try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: toScriptType, changeType: changeScriptType, senderPay: senderPay)
    }

    func fee(inputScriptType: ScriptType, outputScriptType: ScriptType, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) -> Int {
        let emptySignature = Data(repeating: 0, count: TransactionSizeCalculator.signatureLength)
        let emptyPublicKey = Data(repeating: 0, count: TransactionSizeCalculator.pubKeyLength)

        let transactionSize = transactionSizeCalculator.transactionSize(inputs: [inputScriptType], outputScriptTypes: [outputScriptType]) +
                signatureScriptFunction(emptySignature, emptyPublicKey).count

        return transactionSize * feeRate
    }

}
