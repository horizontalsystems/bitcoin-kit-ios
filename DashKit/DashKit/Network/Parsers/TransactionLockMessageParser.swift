import BitcoinCore
// todo identical code with transactionMessageParser
class TransactionLockMessageParser: IMessageParser {
    var id: String { return "ix" }

    func parse(data: Data) -> IMessage {
        return TransactionLockMessage(transaction: TransactionSerializer.deserialize(data: data))
    }

}
