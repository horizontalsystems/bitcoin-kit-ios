import HSCryptoKit

class TransactionBuilder {
    enum BuildError: Error {
        case feeMoreThanValue
        case notSupportedScriptType
    }

    private let inputSigner: IInputSigner
    private let factory: IFactory

    private let outputSetter: OutputSetter
    private let inputSetter: InputSetter
    private let lockTimeSetter: LockTimeSetter
    private let signer: TransactionSigner

    init(inputSigner: IInputSigner, factory: IFactory, outputSetter: OutputSetter, inputSetter: InputSetter, lockTimeSetter: LockTimeSetter, signer: TransactionSigner) {
        self.inputSigner = inputSigner
        self.factory = factory

        self.outputSetter = outputSetter
        self.inputSetter = inputSetter
        self.lockTimeSetter = lockTimeSetter
        self.signer = signer
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

extension TransactionBuilder: ITransactionBuilder {

    func buildTransaction(toAddress: String, value: Int, feeRate: Int, senderPay: Bool, pluginData: [String: [String: Any]]) throws -> FullTransaction {
        let mutableTransaction = MutableTransaction()

        try outputSetter.setOutputs(to: mutableTransaction, toAddress: toAddress, value: value, pluginData: pluginData)
        try inputSetter.setInputs(to: mutableTransaction, feeRate: feeRate, senderPay: senderPay)
        lockTimeSetter.setLockTime(to: mutableTransaction)
        try signer.sign(mutableTransaction: mutableTransaction)

        return mutableTransaction.build()
    }

    func buildTransaction(from unspentOutput: UnspentOutput, to address: Address, fee: Int, lastBlockHeight: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        guard unspentOutput.output.scriptType == .p2sh else {
            throw BuildError.notSupportedScriptType
        }

        guard fee < unspentOutput.output.value else {
            throw BuildError.feeMoreThanValue
        }

        // Add input without unlocking scripts
        let inputToSign = try input(fromUnspentOutput: unspentOutput)

        // Calculate receiveValue
        let receivedValue = unspentOutput.output.value - fee

        // Add :to output
        let output = try factory.output(withIndex: 0, address: address, value: receivedValue, publicKey: nil)

        // Build transaction
        let transaction = factory.transaction(version: 1, lockTime: lastBlockHeight)

        // Sign inputs
        let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        inputToSign.input.signatureScript = signatureScriptFunction(sigScriptData[0], sigScriptData[1])

        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = false

        return FullTransaction(header: transaction, inputs: [inputToSign.input], outputs: [output])
    }

}
