class TransactionBuilder {
    private let recipientSetter: IRecipientSetter
    private let inputSetter: IInputSetter
    private let lockTimeSetter: ILockTimeSetter
    private let outputSetter: IOutputSetter
    private let signer: TransactionSigner

    init(recipientSetter: IRecipientSetter, inputSetter: IInputSetter, lockTimeSetter: ILockTimeSetter, outputSetter: IOutputSetter, signer: TransactionSigner) {
        self.recipientSetter = recipientSetter
        self.inputSetter = inputSetter
        self.lockTimeSetter = lockTimeSetter
        self.outputSetter = outputSetter
        self.signer = signer
    }

}

extension TransactionBuilder: ITransactionBuilder {

    func buildTransaction(toAddress: String, value: Int, feeRate: Int, senderPay: Bool, sortType: TransactionDataSortType, pluginData: [UInt8: IPluginData]) throws -> FullTransaction {
        let mutableTransaction = MutableTransaction()

        try recipientSetter.setRecipient(to: mutableTransaction, toAddress: toAddress, value: value, pluginData: pluginData, skipChecks: false)
        try inputSetter.setInputs(to: mutableTransaction, feeRate: feeRate, senderPay: senderPay, sortType: sortType)
        lockTimeSetter.setLockTime(to: mutableTransaction)

        outputSetter.setOutputs(to: mutableTransaction, sortType: sortType)
        try signer.sign(mutableTransaction: mutableTransaction)

        return mutableTransaction.build()
    }

    func buildTransaction(from unspentOutput: UnspentOutput, toAddress: String, feeRate: Int, sortType: TransactionDataSortType) throws -> FullTransaction {
        let mutableTransaction = MutableTransaction(outgoing: false)

        try recipientSetter.setRecipient(to: mutableTransaction, toAddress: toAddress, value: unspentOutput.output.value, pluginData: [:], skipChecks: false)
        try inputSetter.setInputs(to: mutableTransaction, fromUnspentOutput: unspentOutput, feeRate: feeRate)
        lockTimeSetter.setLockTime(to: mutableTransaction)

        outputSetter.setOutputs(to: mutableTransaction, sortType: sortType)
        try signer.sign(mutableTransaction: mutableTransaction)

        return mutableTransaction.build()
    }

}
