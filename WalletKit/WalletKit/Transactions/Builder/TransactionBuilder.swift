import Foundation

class TransactionBuilder {
    enum BuildError: Error {
        case noPreviousTransaction
        case feeMoreThanValue
    }

    let unspentOutputSelector: UnspentOutputSelector
    let unspentOutputProvider: UnspentOutputProvider
    let transactionSizeCalculator: TransactionSizeCalculator
    let addressConverter: AddressConverter
    let inputSigner: InputSigner
    let scriptBuilder: ScriptBuilder
    let factory: Factory

    init(unspentOutputSelector: UnspentOutputSelector, unspentOutputProvider: UnspentOutputProvider, transactionSizeCalculator: TransactionSizeCalculator, addressConverter: AddressConverter, inputSigner: InputSigner, scriptBuilder: ScriptBuilder, factory: Factory) {
        self.unspentOutputSelector = unspentOutputSelector
        self.unspentOutputProvider = unspentOutputProvider
        self.addressConverter = addressConverter
        self.transactionSizeCalculator = transactionSizeCalculator
        self.inputSigner = inputSigner
        self.scriptBuilder = scriptBuilder
        self.factory = factory
    }

    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String? = nil) throws -> Int {
        var outputType: ScriptType = .p2pkh
        if let string = address, let address = try? addressConverter.convert(address: string) {
            outputType = address.scriptType
        }
        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputType: outputType, senderPay: senderPay, outputs: unspentOutputProvider.allUnspentOutputs())

        let feeWithChangeOutput = selectedOutputsInfo.fee + transactionSizeCalculator.outputSize(type: .p2pkh) * feeRate
        if selectedOutputsInfo.totalValue > value + (senderPay ? feeWithChangeOutput : 0) {
            return feeWithChangeOutput
        } else {
            return selectedOutputsInfo.fee
        }
    }

    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, changeScriptType: ScriptType = .p2pkh, changePubKey: PublicKey, toAddress: String) throws -> Transaction {
        let address = try addressConverter.convert(address: toAddress)

        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputType: address.scriptType, senderPay: senderPay, outputs: unspentOutputProvider.allUnspentOutputs())

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
        if selectedOutputsInfo.totalValue > sentValue + transactionSizeCalculator.outputSize(type: changeScriptType) * feeRate {
            let changeAddress = LegacyAddress(type: changeScriptType.addressType, keyHash: changePubKey.keyHash, base58: changePubKey.address)
            try addOutputToTransaction(transaction: transaction, address: changeAddress, value: selectedOutputsInfo.totalValue - sentValue)
        }

        // Sign inputs
        for i in 0..<transaction.inputs.count {
            let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, index: i)
            transaction.inputs[i].signatureScript = scriptBuilder.unlockingScript(params: sigScriptData)
        }

        transaction.status = .new
        transaction.isMine = true
        transaction.reversedHashHex = Crypto.sha256sha256(TransactionSerializer.serialize(transaction: transaction)).reversedHex
        return transaction
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
        let script = try scriptBuilder.lockingScript(type: address.scriptType, params: [address.keyHash])
        let output = try factory.transactionOutput(withValue: value, index: transaction.outputs.count, lockingScript: script, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash, publicKey: pubKey)
        transaction.outputs.append(output)
    }

}
