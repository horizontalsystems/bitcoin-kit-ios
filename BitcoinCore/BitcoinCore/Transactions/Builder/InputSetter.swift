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
        var value = mutableTransaction.paymentOutput.value
        let extraDataOutputSize = mutableTransaction.extraDataOutputSize
        let unspentOutputInfo = try unspentOutputSelector.select(value: value, feeRate: feeRate, outputScriptType: mutableTransaction.paymentOutput.scriptType, changeType: changeScriptType, senderPay: senderPay)
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

        // change
        let fee = unspentOutputInfo.fee
        var sentValue = value

        if !senderPay {
            sentValue += fee
            value -= fee
            mutableTransaction.paymentOutput.value = value
        }

        if unspentOutputInfo.addChangeOutput {
            let changePubKey = try publicKeyManager.changePublicKey()
            let changeAddress = try addressConverter.convert(publicKey: changePubKey, type: changeScriptType)

            mutableTransaction.changeOutput = try factory.output(withIndex: 1, address: changeAddress, value: unspentOutputInfo.totalValue - sentValue, publicKey: nil)
        }
    }

}
