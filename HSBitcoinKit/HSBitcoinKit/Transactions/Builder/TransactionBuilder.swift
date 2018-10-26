import HSCryptoKit

class TransactionBuilder {
    enum BuildError: Error {
        case noPreviousTransaction
        case noOutputKeyHash
        case feeMoreThanValue
    }

    let unspentOutputSelector: IUnspentOutputSelector
    let unspentOutputProvider: IUnspentOutputProvider
    let transactionSizeCalculator: ITransactionSizeCalculator
    let addressConverter: IAddressConverter
    let inputSigner: IInputSigner
    let scriptBuilder: IScriptBuilder
    let factory: IFactory

    init(unspentOutputSelector: IUnspentOutputSelector, unspentOutputProvider: IUnspentOutputProvider, transactionSizeCalculator: ITransactionSizeCalculator, addressConverter: IAddressConverter, inputSigner: IInputSigner, scriptBuilder: IScriptBuilder, factory: IFactory) {
        self.unspentOutputSelector = unspentOutputSelector
        self.unspentOutputProvider = unspentOutputProvider
        self.addressConverter = addressConverter
        self.transactionSizeCalculator = transactionSizeCalculator
        self.inputSigner = inputSigner
        self.scriptBuilder = scriptBuilder
        self.factory = factory
    }

    private func addInputToTransaction(transaction: Transaction, fromUnspentOutput output: TransactionOutput) throws {
        guard let previousTransaction = output.transaction else {
            throw BuildError.noPreviousTransaction
        }

        let input = factory.transactionInput(withPreviousOutputTxReversedHex: previousTransaction.reversedHashHex, previousOutputIndex: output.index, script: Data(), sequence: 0)
        input.previousOutput = output
        transaction.inputs.append(input)
    }

    private func addOutputToTransaction(transaction: Transaction, address: Address, pubKey: PublicKey? = nil, value: Int) throws {
        let script = try scriptBuilder.lockingScript(for: address)
        let output = try factory.transactionOutput(withValue: value, index: transaction.outputs.count, lockingScript: script, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash, publicKey: pubKey)
        transaction.outputs.append(output)
    }

}

extension TransactionBuilder: ITransactionBuilder {

    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String? = nil) throws -> Int {
        var outputType: ScriptType = .p2pkh
        if let string = address, let address = try? addressConverter.convert(address: string) {
            outputType = address.scriptType
        }
        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputType: outputType, changeType: .p2pkh, senderPay: senderPay, outputs: unspentOutputProvider.allUnspentOutputs())
        return selectedOutputsInfo.fee
    }

    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, changeScriptType: ScriptType = .p2pkh, changePubKey: PublicKey, toAddress: String) throws -> Transaction {
        let address = try addressConverter.convert(address: toAddress)

        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputType: address.scriptType, changeType: changeScriptType, senderPay: senderPay, outputs: unspentOutputProvider.allUnspentOutputs())

        // Build transaction
        let transaction = factory.transaction(version: 1, inputs: [], outputs: [], lockTime: 0)

        // Add inputs without unlocking scripts
        for output in selectedOutputsInfo.outputs {
            try addInputToTransaction(transaction: transaction, fromUnspentOutput: output)
        }

        // Add :to output
        try addOutputToTransaction(transaction: transaction, address: address, value: 0)

        // Calculate fee and add :change output if needed
        if !senderPay {
            guard selectedOutputsInfo.fee < value else {
                throw BuildError.feeMoreThanValue
            }
        }

        let receivedValue = senderPay ? value : value - selectedOutputsInfo.fee
        let sentValue = senderPay ? value + selectedOutputsInfo.fee : value

        transaction.outputs[0].value = receivedValue
        if selectedOutputsInfo.addChangeOutput {
            let changeAddress = try addressConverter.convert(keyHash: changePubKey.keyHash, type: changeScriptType)
            try addOutputToTransaction(transaction: transaction, address: changeAddress, value: selectedOutputsInfo.totalValue - sentValue)
        }

        // Sign inputs
        for i in 0..<transaction.inputs.count {
            let output = selectedOutputsInfo.outputs[i]

            let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, index: i)
            switch output.scriptType {
            case .p2wpkh:
                transaction.segWit = true
                transaction.inputs[i].witnessData.append(objectsIn: sigScriptData)
            case .p2wpkhSh:
                guard let pubKey = output.publicKey else {
                    throw BuildError.noPreviousTransaction
                }
                transaction.segWit = true
                let witnessProgram = OpCode.scriptWPKH(pubKey.keyHash)
                transaction.inputs[i].signatureScript = scriptBuilder.unlockingScript(params: [witnessProgram])
                transaction.inputs[i].witnessData.append(objectsIn: sigScriptData)
            default: transaction.inputs[i].signatureScript = scriptBuilder.unlockingScript(params: sigScriptData)
            }
        }

        transaction.status = .new
        transaction.isMine = true
        transaction.dataHash = CryptoKit.sha256sha256(TransactionSerializer.serialize(transaction: transaction, withoutWitness: true))
        transaction.reversedHashHex = transaction.dataHash.reversedHex
        return transaction
    }

}
