import Foundation

open class TransactionInfo: ITransactionInfo {
    public let transactionHash: String
    public let transactionIndex: Int
    public let from: [TransactionAddressInfo]
    public let to: [TransactionAddressInfo]
    public let amount: Int
    public let fee: Int?
    public let blockHeight: Int?
    public let timestamp: Int

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, fee: Int?, blockHeight: Int?, timestamp: Int) {
        self.transactionHash = transactionHash
        self.transactionIndex = transactionIndex
        self.from = from
        self.to = to
        self.amount = amount
        self.fee = fee
        self.blockHeight = blockHeight
        self.timestamp = timestamp
    }

}

public struct TransactionAddressInfo {
    public let address: String
    public let mine: Bool
}

public struct BlockInfo {
    public let headerHash: String
    public let height: Int
    public let timestamp: Int?
}
