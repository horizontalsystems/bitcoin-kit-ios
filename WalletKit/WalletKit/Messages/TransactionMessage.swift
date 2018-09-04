import Foundation

struct TransactionMessage {
    let transaction: Transaction

    func serialized() -> Data {
        return TransactionSerializer.serialize(transaction: self.transaction)
    }

    static func deserialize(_ data: Data) -> TransactionMessage {
        let byteStream = ByteStream(data)
        let transaction = TransactionSerializer.deserialize(byteStream)

        return TransactionMessage(transaction: transaction)
    }
}
