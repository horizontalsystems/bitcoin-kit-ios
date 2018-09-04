import Foundation

struct TransactionMessage: IMessage{
    let transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    init(_ data: Data) {
        let byteStream = ByteStream(data)
        transaction = TransactionSerializer.deserialize(byteStream)
    }

    func serialized() -> Data {
        return TransactionSerializer.serialize(transaction: self.transaction)
    }

}
