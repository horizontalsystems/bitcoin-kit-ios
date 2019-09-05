import HSCryptoKit

class TransactionBuilder {
    enum BuildError: Error {
        case noChangeAddress
        case feeMoreThanValue
    }

    private let unspentOutputSelector: IUnspentOutputSelector
    private let unspentOutputProvider: IUnspentOutputProvider
    private let publicKeyManager: IPublicKeyManager
    private let addressConverter: IAddressConverter
    private let inputSigner: IInputSigner
    private let factory: IFactory
    private let transactionSizeCalculator: ITransactionSizeCalculator
    private let bip: Bip

    var scriptBuilder: IScriptBuilder

    init(unspentOutputSelector: IUnspentOutputSelector, unspentOutputProvider: IUnspentOutputProvider, publicKeyManager: IPublicKeyManager, addressConverter: IAddressConverter,
         inputSigner: IInputSigner, scriptBuilder: IScriptBuilder, factory: IFactory, transactionSizeCalculator: ITransactionSizeCalculator, bip: Bip) {
        self.unspentOutputSelector = unspentOutputSelector
        self.unspentOutputProvider = unspentOutputProvider
        self.publicKeyManager = publicKeyManager
        self.addressConverter = addressConverter
        self.inputSigner = inputSigner
        self.scriptBuilder = scriptBuilder
        self.factory = factory
        self.transactionSizeCalculator = transactionSizeCalculator
        self.bip = bip
    }

    private func input(fromUnspentOutput unspentOutput: UnspentOutput) throws -> InputToSign {
        if unspentOutput.output.scriptType == .p2wpkh {
            // todo: refactoring version byte!
            // witness key hashes stored with program byte and push code to determine
            // version (current only 0), but for sign we need only public kee hash
            unspentOutput.output.keyHash?.removeFirst(2)
        }

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
            let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: .p2pkh, changeType: .p2pkh, senderPay: senderPay)
            return selectedOutputsInfo.fee
        }
    }

    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, toAddress: String) throws -> FullTransaction {
        guard let changePubKey = try? publicKeyManager.changePublicKey() else {
            throw BuildError.noChangeAddress
        }

        let address = try addressConverter.convert(address: toAddress)
        let selectedOutputsInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: address.scriptType, changeType: bip.scriptType, senderPay: senderPay)

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
            let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: bip.scriptType)
            outputs.append(try output(withIndex: 1, address: changeAddress, value: selectedOutputsInfo.totalValue - sentValue))
        }

        // Build transaction
        let transaction = factory.transaction(version: 1, lockTime: 0)

        // Sign inputs
        for i in 0..<inputsToSign.count {
            let previousUnspentOutput = selectedOutputsInfo.unspentOutputs[i]
            let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: inputsToSign, outputs: outputs, index: i)

            var params = [Data]()
            switch previousUnspentOutput.output.scriptType {
            case .p2wpkh:
                transaction.segWit = true
                inputsToSign[i].input.witnessData.append(contentsOf: sigScriptData)
            case .p2wpkhSh:
                transaction.segWit = true
                inputsToSign[i].input.witnessData.append(contentsOf: sigScriptData)
                params.append(OpCode.scriptWPKH(previousUnspentOutput.publicKey.keyHash))
            default: params.append(contentsOf: sigScriptData)
            }

            inputsToSign[i].input.signatureScript = params.reduce(Data()) { $0 + OpCode.push($1) }
        }

        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = true

        return FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
    }

    func buildTransaction(from unspentOutput: UnspentOutput, to address: String, feeRate: Int, signatureScriptFunction: (Data, Data) -> Data) throws -> FullTransaction {
        let address = try addressConverter.convert(address: address)

        // Calculate fee
        let emptySignature = Data(repeating: 0, count: TransactionSizeCalculator.signatureLength)
        let emptyPublicKey = Data(repeating: 0, count: TransactionSizeCalculator.pubKeyLength)

        let transactionSize = transactionSizeCalculator.transactionSize(inputs: [unspentOutput.output.scriptType], outputScriptTypes: [address.scriptType]) +
                signatureScriptFunction(emptySignature, emptyPublicKey).count
        let fee = transactionSize * feeRate

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
        let transaction = factory.transaction(version: 1, lockTime: 0)

        // Sign inputs
        let sigScriptData = try inputSigner.sigScriptData(transaction: transaction, inputsToSign: [inputToSign], outputs: [output], index: 0)
        inputToSign.input.signatureScript = signatureScriptFunction(sigScriptData[0], sigScriptData[1])

        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = false

        return FullTransaction(header: transaction, inputs: [inputToSign.input], outputs: [output])
    }

}
