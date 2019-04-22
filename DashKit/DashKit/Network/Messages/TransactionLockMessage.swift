import BitcoinCore

struct TransactionLockMessage: IMessage {
    let command: String = "ix"

    let transaction: FullTransaction

}
