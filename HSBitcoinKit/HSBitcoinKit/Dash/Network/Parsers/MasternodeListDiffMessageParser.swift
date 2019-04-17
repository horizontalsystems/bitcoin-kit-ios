import HSCryptoKit

class MasternodeListDiffMessageParser: IMessageParser {
    private let masternodeParser: IMasternodeParser

    var id: String { return "mnlistdiff" }

    init(masternodeParser: IMasternodeParser) {
        self.masternodeParser = masternodeParser
    }

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let baseBlockHash = byteStream.read(Data.self, count: 32)
        let blockHash = byteStream.read(Data.self, count: 32)
        let totalTransactions = byteStream.read(UInt32.self)
        let merkleHashesCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)

        var merkleHashes = [Data]()
        for _ in 0..<merkleHashesCount {
            merkleHashes.append(byteStream.read(Data.self, count: 32))
        }

        let merkleFlagsCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        let merkleFlags = byteStream.read(Data.self, count: Int(merkleFlagsCount))
        let cbTx = CoinbaseTransaction(byteStream: byteStream)

        let deletedMNsCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        var deletedMNs = [Data]()
        for _ in 0..<deletedMNsCount {
            deletedMNs.append(byteStream.read(Data.self, count: 32))
        }

        let mnListCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        var mnList = [Masternode]()
        for _ in 0..<mnListCount {
            mnList.append(masternodeParser.parse(byteStream: byteStream))
        }

        return MasternodeListDiffMessage(baseBlockHash: baseBlockHash,
                blockHash: blockHash,
                totalTransactions: totalTransactions,
                merkleHashesCount: merkleHashesCount,
                merkleHashes: merkleHashes,
                merkleFlagsCount: merkleFlagsCount,
                merkleFlags: merkleFlags,
                cbTx: cbTx,
                deletedMNsCount: deletedMNsCount,
                deletedMNs: deletedMNs,
                mnListCount: mnListCount,
                mnList: mnList)
    }

}
