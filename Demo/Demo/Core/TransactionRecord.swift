import Foundation

struct TransactionRecord {
    let transactionHash: String
    let status: TransactionStatus
    let transactionIndex: Int

    let amount: Decimal
    let fee: Decimal?
    let timestamp: Double

    let from: [TransactionAddress]
    let to: [TransactionAddress]

    let blockHeight: Int?

    var transactionExtraType: String?
}

struct TransactionAddress {
    let address: String
    let mine: Bool
    let pluginId: UInt8?
    let pluginData: Any?
}

enum TransactionStatus: Int {
    case new, relayed, invalid
}