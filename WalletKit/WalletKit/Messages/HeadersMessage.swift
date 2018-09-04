import Foundation

struct HeadersMessage: IMessage{
    let count: VarInt
    let blockHeaders: [BlockHeader]

    init(_ data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var headers = [BlockHeader]()
        for _ in 0..<Int(count.underlyingValue) {
            headers.append(BlockHeaderSerializer.deserialize(fromByteStream: byteStream))
            _ = byteStream.read(Data.self, count: 1)
        }

        blockHeaders = headers
    }

    public func serialized() -> Data {
        var data = Data()
        data += count.serialized()
        data += blockHeaders.flatMap { BlockHeaderSerializer.serialize(header: $0) }
        return data
    }

}
