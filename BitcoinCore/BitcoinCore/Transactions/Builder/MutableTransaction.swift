public class MutableTransaction {
    var transaction = Transaction(version: 1, lockTime: 0)
    var inputsToSign = [InputToSign]()

    public var recipientAddress: Address!
    var recipientValue = 0
    var changeAddress: Address? = nil
    var changeValue = 0

    private var extraData = [Int: Data]()

    var outputs: [Output] {
        var outputs = [Output]()

        var index = 0

        if let address = recipientAddress {
            outputs.append(Output(withValue: recipientValue, index: index, lockingScript: address.lockingScript, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash))
            index += 1
        }

        if let address = changeAddress {
            outputs.append(Output(withValue: changeValue, index: index, lockingScript: address.lockingScript, type: address.scriptType, address: address.stringValue, keyHash: address.keyHash))
            index += 1
        }

        if !extraData.isEmpty {
            var data = Data([OpCode.op_return])

            extraData.forEach { key, value in
                data += OpCode.push(key) + value
            }

            outputs.append(Output(withValue: 0, index: index, lockingScript: data, type: .nullData))
        }

        return outputs
    }

    var extraDataOutputSize: Int {
        0
    }

    init() {
        transaction.status = .new
        transaction.isMine = true
        transaction.isOutgoing = true
    }

    public func add(extraData: Data, pluginId: Int) {
        self.extraData[pluginId] = extraData
    }

    func add(inputToSign: InputToSign) {
        inputsToSign.append(inputToSign)
    }

    func build() -> FullTransaction {
        FullTransaction(header: transaction, inputs: inputsToSign.map{ $0.input }, outputs: outputs)
    }

}
