import Foundation

struct TransactionAddress {
    let address: String
    let mine: Bool
}
struct TransactionRecord {
    let transactionHash: String
    let from: [TransactionAddress]
    let to: [TransactionAddress]
    let amount: Double
    let fee: Double
    let blockHeight: Int?
    let timestamp: Int?
}
