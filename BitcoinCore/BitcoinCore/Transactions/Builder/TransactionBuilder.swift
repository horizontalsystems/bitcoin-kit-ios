import HSCryptoKit

class TransactionBuilder {
    enum BuildError: Error {
        case feeMoreThanValue
        case notSupportedScriptType
    }

    private let inputSigner: IInputSigner
    private let scriptBuilder: IScriptBuilder
    private let factory: IFactory

    init(inputSigner: IInputSigner, scriptBuilder: IScriptBuilder, factory: IFactory) {
        self.inputSigner = inputSigner
        self.scriptBuilder = scriptBuilder
        self.factory = factory
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

    private func output(withIndex index: Int, address: Address, value: Int) throws -> Output {
        let script = try scriptBuilder.lockingScript(for: address)
        return factory.output(withValue: value, index: index, lockingScript: script, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash, publicKey: nil)
    }

}

extension TransactionBuilder: ITransactionBuilder {

    func buildTransaction(value: Int, unspentOutputs: [UnspentOutput], fee: Int, senderPay: Bool, toAddress: Address, changeAddress: Address?, lastBlockHeight: Int) throws -> FullTransaction {
        if !senderPay {
            guard fee < value else {
                throw BuildError.feeMoreThanValue
            }
        }

        var inputsToSign = [InputToSign]()
        var outputs = [Output]()

        // Add inputs without unlocking scripts
        for output in unspentOutputs {
            inputsToSign.append(try input(fromUnspentOutput: output))
        }

        // Calculate fee
        let receivedValue = senderPay ? value : value - fee
        let sentValue = senderPay ? value + fee : value

        // Add :to output
        outputs.append(try output(withIndex: 0, address: toAddress, value: receivedValue))

        // Add :change output if needed
        if let changeAddress = changeAddress {
            let totalValue = unspentOutputs.reduce(0) { $0 + $1.output.value }
            outputs.append(try output(withIndex: 1, address: changeAddress, value: totalValue - sentValue))
        }

        // Build transaction
        let transaction = factory.transaction(version: 1, lockTime: lastBlockHeight)

        // Sign inputs
        for i in 0..<inputsToSign.count {
            let previousUnspentOutput = unspentOutputs[i]
            let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: inputsToSign, outputs: outputs, index: i)

            var params = [Data]()
            switch previousUnspentOutput.output.scriptType {
            case .p2pkh:
                params.append(contentsOf: sigScriptData)
            case .p2wpkh:
                transaction.segWit = true
                inputsToSign[i].input.witnessData = sigScriptData
            case .p2wpkhSh:
                transaction.segWit = true
                inputsToSign[i].input.witnessData = sigScriptData
                params.append(OpCode.scriptWPKH(previousUnspentOutput.publicKey.keyHash))
            default: throw BuildError.notSupportedScriptType
            }

            inputsToSign[i].input.signatureScript = params.reduce(Data()) { $0 + OpCode.push($1) }
        }

        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = true

        return FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
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
        let output = try self.output(withIndex: 0, address: address, value: receivedValue)

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
