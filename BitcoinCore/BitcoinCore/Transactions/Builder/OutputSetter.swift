class OutputSetter {
    private let addressConverter: IAddressConverter
    private let factory: IFactory
    private let pluginManager: IPluginManager
    private let dustCalculator: IDustCalculator

    init(addressConverter: IAddressConverter, factory: IFactory, pluginManager: IPluginManager, dustCalculator: IDustCalculator) {
        self.addressConverter = addressConverter
        self.factory = factory
        self.pluginManager = pluginManager
        self.dustCalculator = dustCalculator
    }

}

extension OutputSetter: IOutputSetter {

    func setOutputs(to mutableTransaction: MutableTransaction, toAddress: String, value: Int, pluginData: [UInt8: IPluginData]) throws {
        let address = try addressConverter.convert(address: toAddress)

        if value < dustCalculator.dust(type: address.scriptType) {
            throw BitcoinCoreErrors.SendValueErrors.dust
        }

        mutableTransaction.recipientAddress = address
        mutableTransaction.recipientValue = value

        try pluginManager.processOutputs(mutableTransaction: mutableTransaction, pluginData: pluginData)
    }

}
