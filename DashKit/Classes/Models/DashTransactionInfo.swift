import BitcoinCore

public class DashTransactionInfo: TransactionInfo {
    public var instantTx: Bool = false

    private enum CodingKeys: String, CodingKey {
        case instantTx
    }

    public required init(uid: String, transactionHash: String, transactionIndex: Int, inputs: [TransactionInputInfo], outputs: [TransactionOutputInfo], amount: Int, type: TransactionType, fee: Int?, blockHeight: Int?, timestamp: Int, status: TransactionStatus, conflictingHash: String?) {
        super.init(uid: uid, transactionHash: transactionHash, transactionIndex: transactionIndex, inputs: inputs, outputs: outputs, amount: amount, type: type, fee: fee, blockHeight: blockHeight, timestamp: timestamp, status: status, conflictingHash: conflictingHash)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        instantTx = try container.decode(Bool.self, forKey: .instantTx)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instantTx, forKey: .instantTx)

        try super.encode(to: encoder)
    }

}
