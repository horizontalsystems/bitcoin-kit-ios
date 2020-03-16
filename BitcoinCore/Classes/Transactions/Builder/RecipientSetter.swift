class RecipientSetter {
    private let addressConverter: IAddressConverter
    private let pluginManager: IPluginManager

    init(addressConverter: IAddressConverter, pluginManager: IPluginManager) {
        self.addressConverter = addressConverter
        self.pluginManager = pluginManager
    }

}

extension RecipientSetter: IRecipientSetter {

    func setRecipient(to mutableTransaction: MutableTransaction, toAddress: String, value: Int, pluginData: [UInt8: IPluginData], skipChecks: Bool = false) throws {
        mutableTransaction.recipientAddress = try addressConverter.convert(address: toAddress)
        mutableTransaction.recipientValue = value

        try pluginManager.processOutputs(mutableTransaction: mutableTransaction, pluginData: pluginData, skipChecks: skipChecks)
    }

}
