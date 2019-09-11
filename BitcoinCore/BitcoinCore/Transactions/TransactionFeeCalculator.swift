class TransactionFeeCalculator {

    private let unspentOutputSelector: IUnspentOutputSelector
    private let transactionSizeCalculator: ITransactionSizeCalculator
    private let transactionBuilder: ITransactionBuilder

    init(unspentOutputSelector: IUnspentOutputSelector, transactionSizeCalculator: ITransactionSizeCalculator, transactionBuilder: ITransactionBuilder) {
        self.unspentOutputSelector = unspentOutputSelector
        self.transactionSizeCalculator = transactionSizeCalculator
        self.transactionBuilder = transactionBuilder
    }

}

extension TransactionFeeCalculator: ITransactionFeeCalculator {

    // :fee method returns the fee for the given amount
    // If address given and it's valid, it returns the actual fee
    // Otherwise, it returns the estimated fee
    func fee(for value: Int, feeRate: Int, senderPay: Bool, toAddress: Address?, changeAddress: Address) throws -> Int {
        if let address = toAddress {
            // Actual fee
            let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: address.scriptType, changeType: changeAddress.scriptType, senderPay: senderPay)
            let transaction = try transactionBuilder.buildTransaction(
                    value: value, unspentOutputs: selectedOutputsInfo.unspentOutputs, fee: selectedOutputsInfo.fee, senderPay: senderPay,
                    toAddress: address, changeAddress: selectedOutputsInfo.addChangeOutput ? changeAddress : nil
            )
            return TransactionSerializer.serialize(transaction: transaction, withoutWitness: true).count * feeRate
        } else {
            // Estimated fee
            // Default to .p2pkh address
            let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: changeAddress.scriptType, changeType: changeAddress.scriptType, senderPay: senderPay)
            return selectedOutputsInfo.fee
        }
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
