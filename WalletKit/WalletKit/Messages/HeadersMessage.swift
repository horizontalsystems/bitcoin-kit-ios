import Foundation

struct HeadersMessage: IMessage {
    let count: VarInt
    let blockHeaders: [BlockHeader]

    init(data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var blockHeaders = [BlockHeader]()
        for _ in 0..<Int(count.underlyingValue) {
            blockHeaders.append(BlockHeaderSerializer.deserialize(byteStream: byteStream))
            _ = byteStream.read(Data.self, count: 1)
        }

        self.blockHeaders = blockHeaders
    }

    func serialized() -> Data {
        var data = Data()
        data += count.serialized()
        data += blockHeaders.flatMap {
            BlockHeaderSerializer.serialize(header: $0)
        }
        return data
    }

}
