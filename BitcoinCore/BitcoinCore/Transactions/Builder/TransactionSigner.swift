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

            switch previousOutput.scriptType {
            case .p2pkh:
                inputToSign.input.signatureScript = sigScriptData.reduce(Data()) { $0 + OpCode.push($1) }
            case .p2wpkh:
                mutableTransaction.transaction.segWit = true
                inputToSign.input.witnessData = sigScriptData
            case .p2wpkhSh:
                mutableTransaction.transaction.segWit = true
                inputToSign.input.witnessData = sigScriptData
                inputToSign.input.signatureScript = OpCode.push(OpCode.scriptWPKH(publicKey.keyHash))
            default: throw SignError.notSupportedScriptType
            }
        }
    }

}
