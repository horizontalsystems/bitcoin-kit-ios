import Foundation

struct TransactionRecord {
    let transactionHash: String
    let transactionIndex: Int

    let amount: Decimal
    let timestamp: Double

    let from: [TransactionAddress]
    let to: [TransactionAddress]

    let blockHeight: Int?

    var transactionExtraType: String?
}

struct TransactionAddress {
    let address: String
    let mine: Bool
}
