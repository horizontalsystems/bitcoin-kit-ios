import UIExtensions

struct TransactionMessage: IMessage {
    let transaction: FullTransaction
    let size: Int

    var description: String {
        return "\(transaction.header.dataHash.reversedHex)"
    }

}
