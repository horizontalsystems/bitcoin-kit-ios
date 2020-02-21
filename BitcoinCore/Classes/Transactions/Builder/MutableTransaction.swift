public class MutableTransaction {
    var transaction = Transaction(version: 2, lockTime: 0)
    var inputsToSign = [InputToSign]()

    public var recipientAddress: Address!
    public var recipientValue = 0
    var changeAddress: Address? = nil
    var changeValue = 0

    private var pluginData = [UInt8: Data]()

    var outputs: [Output] {
        var outputs = [Output]()

        if let address = recipientAddress {
            outputs.append(Output(withValue: recipientValue, index: 0, lockingScript: address.lockingScript, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash))
        }

        if let address = changeAddress {
            outputs.append(Output(withValue: changeValue, index: 0, lockingScript: address.lockingScript, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash))
        }

        if !pluginData.isEmpty {
            var data = Data([OpCode.op_return])

            pluginData.forEach { key, value in
                data += Data([key]) + value
            }

            outputs.append(Output(withValue: 0, index: 0, lockingScript: data, type: .nullData))
        }

        outputs.sort(by: Bip69.outputComparator)

        outputs.enumerated().forEach { index, transactionOutput in
            transactionOutput.index = index
        }

        return outputs
    }

    var pluginDataOutputSize: Int {
        pluginData.count > 0 ? 1 + pluginData.reduce(into: 0) { $0 += 1 + $1.value.count } : 0                // OP_RETURN (PLUGIN_ID PLUGIN_DATA)
    }

    public init(outgoing: Bool = true) {
        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = outgoing
    }

    public func add(pluginData: Data, pluginId: UInt8) {
        self.pluginData[pluginId] = pluginData
    }

    func add(inputToSign: InputToSign) {
        inputsToSign.append(inputToSign)
    }

    public func build() -> FullTransaction {
        FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
    }

}
