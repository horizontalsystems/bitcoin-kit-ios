import HSCryptoKit

class TransactionBuilder {
    enum BuildError: Error {
        case noChangeAddress
        case feeMoreThanValue
    }

    private let unspentOutputSelector: IUnspentOutputSelector
    private let unspentOutputProvider: IUnspentOutputProvider
    private let addressManager: IAddressManager
    private let addressConverter: IAddressConverter
    private let inputSigner: IInputSigner
    private let scriptBuilder: IScriptBuilder
    private let factory: IFactory

    init(unspentOutputSelector: IUnspentOutputSelector, unspentOutputProvider: IUnspentOutputProvider, addressManager: IAddressManager, addressConverter: IAddressConverter, inputSigner: IInputSigner, scriptBuilder: IScriptBuilder, factory: IFactory) {
        self.unspentOutputSelector = unspentOutputSelector
        self.unspentOutputProvider = unspentOutputProvider
        self.addressManager = addressManager
        self.addressConverter = addressConverter
        self.inputSigner = inputSigner
        self.scriptBuilder = scriptBuilder
        self.factory = factory
    }

    private func input(fromUnspentOutput unspentOutput: UnspentOutput) throws -> InputToSign {
        return factory.inputToSign(withPreviousOutput: unspentOutput, script: Data(), sequence: 0xFFFFFFFF)
    }

    private func output(withIndex index: Int, address: Address, pubKey: PublicKey? = nil, value: Int) throws -> Output {
        let script = try scriptBuilder.lockingScript(for: address)
        let output = factory.output(withValue: value, index: index, lockingScript: script, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash, publicKey: pubKey)
        return output
    }

}

extension TransactionBuilder: ITransactionBuilder {

    // :fee method returns the fee for the given amount
    // If address given and it's valid, it returns the actual fee
    // Otherwise, it returns the estimated fee
    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String? = nil) throws -> Int {
        if let string = address, let _ = try? addressConverter.convert(address: string) {
            // Actual fee
            let transaction = try buildTransaction(value: value, feeRate: feeRate, senderPay: senderPay, toAddress: string)
            return TransactionSerializer.serialize(transaction: transaction, withoutWitness: true).count * feeRate
        } else {
            // Estimated fee
            // Default to .p2pkh address
            let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: senderPay, unspentOutputs: unspentOutputProvider.allUnspentOutputs)
            return selectedOutputsInfo.fee
        }
    }

    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, toAddress: String) throws -> FullTransaction {
        guard let changePubKey = try? addressManager.changePublicKey() else {
            throw BuildError.noChangeAddress
        }

        let changeScriptType = ScriptType.p2pkh
        let address = try addressConverter.convert(address: toAddress)
        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: address.scriptType, changeType: changeScriptType, senderPay: senderPay, unspentOutputs: unspentOutputProvider.allUnspentOutputs)

        if !senderPay {
            guard selectedOutputsInfo.fee < value else {
                throw BuildError.feeMoreThanValue
            }
        }

        var inputsToSign = [InputToSign]()
        var outputs = [Output]()

        // Add inputs without unlocking scripts
        for output in selectedOutputsInfo.unspentOutputs {
            inputsToSign.append(try input(fromUnspentOutput: output))
        }

        // Calculate fee
        let receivedValue = senderPay ? value : value - selectedOutputsInfo.fee
        let sentValue = senderPay ? value + selectedOutputsInfo.fee : value

        // Add :to output
        outputs.append(try output(withIndex: 0, address: address, value: receivedValue))

        // Add :change output if needed
        if selectedOutputsInfo.addChangeOutput {
            let changeAddress = try addressConverter.convert(keyHash: changePubKey.keyHash, type: changeScriptType)
            outputs.append(try output(withIndex: 1, address: changeAddress, value: selectedOutputsInfo.totalValue - sentValue))
        }

        // Build transaction
        let transaction = factory.transaction(version: 1, lockTime: 0)

        // Sign inputs
        for i in 0..<inputsToSign.count {
            let previousUnspentOutput = selectedOutputsInfo.unspentOutputs[i]

            let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: inputsToSign, outputs: outputs, index: i)
            switch previousUnspentOutput.output.scriptType {
            case .p2wpkh:
                transaction.segWit = true
                inputsToSign[i].input.witnessData.append(contentsOf: sigScriptData)
            case .p2wpkhSh:
                transaction.segWit = true
                let witnessProgram = OpCode.scriptWPKH(previousUnspentOutput.publicKey.keyHash)
                inputsToSign[i].input.signatureScript = scriptBuilder.unlockingScript(params: [witnessProgram])
                inputsToSign[i].input.witnessData.append(contentsOf: sigScriptData)
            default: inputsToSign[i].input.signatureScript = scriptBuilder.unlockingScript(params: sigScriptData)
            }
        }

        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = true

        return FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
    }

}
