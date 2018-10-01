import Foundation

struct TransactionMessage: IMessage {
    let transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    init(data: Data, network: NetworkProtocol) {
        transaction = TransactionSerializer.deserialize(data: data)
    }

    init(transactionData: Data) {
        transaction = TransactionSerializer.deserialize(data: transactionData)
    }

    func serialized() -> Data {
        return TransactionSerializer.serialize(transaction: transaction)
    }

}
