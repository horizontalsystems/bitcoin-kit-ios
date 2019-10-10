class InputSetter {
    private let unspentOutputSelector: IUnspentOutputSelector
    private let addressConverter: IAddressConverter
    private let publicKeyManager: IPublicKeyManager
    private let factory: IFactory
    private let changeScriptType: ScriptType

    init(unspentOutputSelector: IUnspentOutputSelector, addressConverter: IAddressConverter, publicKeyManager: IPublicKeyManager,
         factory: IFactory, changeScriptType: ScriptType) {
        self.unspentOutputSelector = unspentOutputSelector
        self.addressConverter = addressConverter
        self.publicKeyManager = publicKeyManager
        self.factory = factory
        self.changeScriptType = changeScriptType
    }

    func setInputs(to mutableTransaction: MutableTransaction, feeRate: Int, senderPay: Bool) throws {
        let value = mutableTransaction.recipientValue
        _ = mutableTransaction.pluginDataOutputSize
        let unspentOutputInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: mutableTransaction.recipientAddress.scriptType, changeType: changeScriptType, senderPay: senderPay)
        let unspentOutputs = unspentOutputInfo.unspentOutputs

        for unspentOutput in unspentOutputs {
            if unspentOutput.output.scriptType == .p2wpkh {
                // todo: refactoring version byte!
                // witness key hashes stored with program byte and push code to determine
                // version (current only 0), but for sign we need only public kee hash
                unspentOutput.output.keyHash?.removeFirst(2)
            }

            // Maximum nSequence value (0xFFFFFFFF) disables nLockTime.
            // According to BIP-125, any value less than 0xFFFFFFFE makes a Replace-by-Fee(RBF) opted in.
            let sequence = 0xFFFFFFFE

            let input = factory.inputToSign(withPreviousOutput: unspentOutput, script: Data(), sequence: sequence)
            mutableTransaction.add(inputToSign: input)
        }

        // Calculate fee
        let fee = unspentOutputInfo.fee
        let receivedValue = senderPay ? value : value - fee
        let sentValue = senderPay ? value + fee : value

        // Set received value
        mutableTransaction.recipientValue = receivedValue

        // Add change output if needed
        if unspentOutputInfo.addChangeOutput {
            let changePubKey = try publicKeyManager.changePublicKey()
            let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: changeScriptType)

            mutableTransaction.changeAddress = changeAddress
            mutableTransaction.changeValue = unspentOutputInfo.totalValue - sentValue
        }
    }

}
