import BitcoinCore

struct TransactionLockMessage: IMessage {

    let transaction: FullTransaction

    var description: String {
        return "\(transaction.header.dataHash.reversedHex)"
    }

}
