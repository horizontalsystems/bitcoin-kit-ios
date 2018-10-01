import Foundation

struct BlockMessage: IMessage {
    let blockHeaderItem: BlockHeader

    /// Number of transaction entries
    let transactionCount: VarInt
    /// Block transactions, in format of "tx" command
    let transactions: [Transaction]

    init(data: Data, network: NetworkProtocol) {
        let byteStream = ByteStream(data)

        blockHeaderItem = BlockHeaderSerializer.deserialize(byteStream: byteStream)
        transactionCount = byteStream.read(VarInt.self)

        var transactions = [Transaction]()
        for _ in 0..<transactionCount.underlyingValue {
            transactions.append(TransactionSerializer.deserialize(byteStream: byteStream))
        }

        self.transactions = transactions
    }

    func serialized() -> Data {
        var data = Data()
        data += BlockHeaderSerializer.serialize(header: blockHeaderItem)
        data += transactionCount.serialized()
        for transaction in transactions {
            data += TransactionSerializer.serialize(transaction: transaction)
        }
        return data
    }

}
