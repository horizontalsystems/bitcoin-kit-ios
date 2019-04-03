import Foundation

struct TransactionMessage: IMessage {
    let command: String = "tx"

    let transaction: FullTransaction

}
