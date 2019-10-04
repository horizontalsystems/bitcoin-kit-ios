class OutputSetter {
    private let addressConverter: IAddressConverter
    private let factory: IFactory

    init(addressConverter: IAddressConverter, factory: IFactory) {
        self.addressConverter = addressConverter
        self.factory = factory
    }

    func setOutputs(to transaction: MutableTransaction, toAddress: String, value: Int, extraData: [String: [String: Any]]) throws {
        let address = try addressConverter.convert(address: toAddress)
        transaction.paymentOutput = try factory.output(withIndex: 0, address: address, value: value, publicKey: nil)

        // plugins.setOutputs(transaction, extraData)
    }

}
