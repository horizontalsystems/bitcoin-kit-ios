import Foundation

public struct TransactionInfo {
    public let transactionHash: String
    public let from: [TransactionAddress]
    public let to: [TransactionAddress]
    public let amount: Int
    public let blockHeight: Int?
    public let timestamp: Int?
}

public struct TransactionAddress {
    public let address: String
    public let mine: Bool
}

public struct BlockInfo {
    public let headerHash: String
    public let height: Int
    public let timestamp: Int?
}
