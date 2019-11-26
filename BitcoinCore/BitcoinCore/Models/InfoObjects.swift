import Foundation

open class TransactionInfo: ITransactionInfo, Codable {
    public let transactionHash: String
    public let transactionIndex: Int
    public let from: [TransactionAddressInfo]
    public let to: [TransactionAddressInfo]
    public let amount: Int
    public let fee: Int?
    public let blockHeight: Int?
    public let timestamp: Int
    public let status: TransactionStatus

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, fee: Int?, blockHeight: Int?,
                         timestamp: Int, status: TransactionStatus) {
        self.transactionHash = transactionHash
        self.transactionIndex = transactionIndex
        self.from = from
        self.to = to
        self.amount = amount
        self.fee = fee
        self.blockHeight = blockHeight
        self.timestamp = timestamp
        self.status = status
    }

}

public class TransactionAddressInfo: Codable {
    public let address: String
    public let mine: Bool
    public var pluginId: UInt8? = nil
    public var pluginData: IPluginOutputData? = nil

    var pluginDataString: String? = nil

    private enum CodingKeys: String, CodingKey {
        case address, mine, pluginId, pluginDataString
    }

    public init(address: String, mine: Bool) {
        self.address = address
        self.mine = mine
    }

}

public struct BlockInfo {
    public let headerHash: String
    public let height: Int
    public let timestamp: Int?
}

public struct BalanceInfo : Equatable {
    public let spendable: Int
    public let unspendable: Int

    public static func ==(lhs: BalanceInfo, rhs: BalanceInfo) -> Bool {
        lhs.spendable == rhs.spendable && lhs.unspendable == rhs.unspendable
    }
}
