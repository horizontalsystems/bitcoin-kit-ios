import BitcoinCore

struct CoinbaseTransaction {
    private let coinbasePayloadSize = 70    // additional size of coinbase v2 parameters
    let transaction: FullTransaction
    let coinbaseTransactionSize: Data
    let version: UInt16
    let height: UInt32
    let merkleRootMNList: Data
    let merkleRootQuorums: Data?

    init(transaction: FullTransaction, coinbaseTransactionSize: Data, version: UInt16, height: UInt32, merkleRootMNList: Data, merkleRootQuorums: Data? = nil) {
        self.transaction = transaction
        self.coinbaseTransactionSize = coinbaseTransactionSize
        self.version = version
        self.height = height
        self.merkleRootMNList = merkleRootMNList
        self.merkleRootQuorums = merkleRootQuorums
    }

    init(byteStream: ByteStream) {
        transaction = TransactionSerializer.deserialize(byteStream: byteStream)
        let size = byteStream.read(VarInt.self)
        coinbaseTransactionSize = size.data
        version = byteStream.read(UInt16.self)
        height = byteStream.read(UInt32.self)
        merkleRootMNList = byteStream.read(Data.self, count: 32)
        merkleRootQuorums = version >= 2 ? byteStream.read(Data.self, count: 32) : nil

        let needToRead = Int(size.underlyingValue) - coinbasePayloadSize
        if needToRead > 0 {
            _ = byteStream.read(Data.self, count: needToRead)
        }
    }

}
