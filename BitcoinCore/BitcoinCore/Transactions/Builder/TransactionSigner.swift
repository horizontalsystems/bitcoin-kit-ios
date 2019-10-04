class TransactionSigner {
    enum SignError: Error {
        case notSupportedScriptType
    }

    private let inputSigner: IInputSigner

    init(inputSigner: IInputSigner) {
        self.inputSigner = inputSigner
    }

    func sign(mutableTransaction: MutableTransaction) throws {
        for (index, inputToSign) in mutableTransaction.inputsToSign.enumerated() {
            let previousOutput = inputToSign.previousOutput
            let publicKey = inputToSign.previousOutputPublicKey

            let sigScriptData = try inputSigner.sigScriptData(
                    transaction: mutableTransaction.transaction,
                    inputsToSign: mutableTransaction.inputsToSign,
                    outputs: mutableTransaction.outputs,
                    index: index
            )

            var params = [Data]()
            switch previousOutput.scriptType {
            case .p2pkh:
                params.append(contentsOf: sigScriptData)
            case .p2wpkh:
                mutableTransaction.transaction.segWit = true
                inputToSign.input.witnessData = sigScriptData
            case .p2wpkhSh:
                mutableTransaction.transaction.segWit = true
                inputToSign.input.witnessData = sigScriptData
                params.append(OpCode.scriptWPKH(publicKey.keyHash))
            default: throw SignError.notSupportedScriptType
            }

            inputToSign.input.signatureScript = params.reduce(Data()) { $0 + OpCode.push($1) }
        }
    }

}
