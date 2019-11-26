import BitcoinCore

public class DashTransactionInfo: TransactionInfo {
    public var instantTx: Bool = false

    private enum CodingKeys: String, CodingKey {
        case instantTx
    }

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, fee: Int?, blockHeight: Int?, timestamp: Int, status: TransactionStatus) {
        super.init(transactionHash: transactionHash, transactionIndex: transactionIndex, from: from, to: to, amount: amount, fee: fee, blockHeight: blockHeight, timestamp: timestamp, status: status)
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
