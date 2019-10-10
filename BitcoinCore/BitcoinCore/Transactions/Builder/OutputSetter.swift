class OutputSetter {
    private let addressConverter: IAddressConverter
    private let factory: IFactory
    private let pluginManager: IPluginManager

    init(addressConverter: IAddressConverter, factory: IFactory, pluginManager: IPluginManager) {
        self.addressConverter = addressConverter
        self.factory = factory
        self.pluginManager = pluginManager
    }

    func setOutputs(to mutableTransaction: MutableTransaction, toAddress: String, value: Int, pluginData: [String: [String: Any]]) throws {
        mutableTransaction.recipientAddress = try addressConverter.convert(address: toAddress)
        mutableTransaction.recipientValue = value

        try pluginManager.processOutputs(mutableTransaction: mutableTransaction, pluginData: pluginData)
    }

}
