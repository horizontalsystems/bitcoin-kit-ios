import HSCryptoKit

class GetMasternodeListDiffMessageParser: ListElement<Data, IMessage> {  // "getmnlistd"

    override func process(_ request: Data) -> IMessage? {
        let byteStream = ByteStream(request)

        let baseBlockHash = byteStream.read(Data.self, count: 32)
        let blockHash = byteStream.read(Data.self, count: 32)

        return GetMasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash)
    }

}
