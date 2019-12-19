import Foundation

struct TransactionRecord {
    let uid: String
    let transactionHash: String
    let transactionIndex: Int
    let interTransactionIndex: Int
    let status: TransactionStatus
    let type: TransactionType
    let blockHeight: Int?
    let amount: Decimal
    let fee: Decimal?
    let date: Date
    let from: [TransactionInputOutput]
    let to: [TransactionInputOutput]
    var transactionExtraType: String?
}

struct TransactionInputOutput {
    let mine: Bool
    let address: String?
    let value: Int?
    let changeOutput: Bool
    let pluginId: UInt8?
    let pluginData: Any?
}

enum TransactionStatus: Int {
    case new, relayed, invalid
}

enum TransactionType {
    case incoming, outgoing, sentToSelf(enteredAmount: Decimal)

    var description: String {
        switch self {
        case .incoming: return "incoming"
        case .outgoing: return "outgoing"
        case .sentToSelf(let possibleEnteredAmount): return "sentToSelf: \(possibleEnteredAmount.formattedAmount)"
        }
    }

}
