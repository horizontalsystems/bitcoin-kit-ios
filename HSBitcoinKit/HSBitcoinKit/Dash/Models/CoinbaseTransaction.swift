struct CoinbaseTransaction {
    let transaction: Transaction
    let coinbaseTransactionSize: Data
    let version: UInt16
    let height: UInt32
    let merkleRootMNList: Data

    init(transaction: Transaction, coinbaseTransactionSize: Data, version: UInt16, height: UInt32, merkleRootMNList: Data) {
        self.transaction = transaction
        self.coinbaseTransactionSize = coinbaseTransactionSize
        self.version = version
        self.height = height
        self.merkleRootMNList = merkleRootMNList
    }

    init(byteStream: ByteStream) {
        transaction = TransactionSerializer.deserialize(byteStream: byteStream)
        coinbaseTransactionSize = (byteStream.read(VarInt.self)).data
        version = byteStream.read(UInt16.self)
        height = byteStream.read(UInt32.self)
        merkleRootMNList = byteStream.read(Data.self, count: 32)
    }

}
