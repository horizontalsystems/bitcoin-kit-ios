public class MutableTransaction {
    var transaction = Transaction(version: 2, lockTime: 0)
    var inputsToSign = [InputToSign]()
    var outputs = [Output]()

    public var recipientAddress: Address!
    public var recipientValue = 0
    var changeAddress: Address? = nil
    var changeValue = 0

    private(set) var pluginData = [UInt8: Data]()

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
        FullTransaction(header: transaction, inputs: inputsToSign.map { $0.input }, outputs: outputs)
    }

}
