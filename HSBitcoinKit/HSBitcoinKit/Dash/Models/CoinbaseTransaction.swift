class CoinbaseTransaction {
    let transaction: Transaction
    let coinbaseTransactionSize: UInt32
    let version: UInt16
    let height: UInt32
    let merkleRootMNList: Data

    init(byteStream: ByteStream) {
        transaction = TransactionSerializer.deserialize(byteStream: byteStream)
        coinbaseTransactionSize = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        version = byteStream.read(UInt16.self)
        height = byteStream.read(UInt32.self)
        merkleRootMNList = byteStream.read(Data.self, count: 32)
    }

}
