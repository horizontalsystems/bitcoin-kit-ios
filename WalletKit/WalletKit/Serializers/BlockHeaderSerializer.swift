import Foundation

class BlockHeaderSerializer {
    static func serialize(header: BlockHeader) -> Data {
        var data = Data()
        data += Int32(header.version)
        data += header.previousBlockHeaderHash
        data += header.merkleRoot
        data += UInt32(header.timestamp)
        data += UInt32(header.bits)
        data += UInt32(header.nonce)
        return data
    }

    static func deserialize(fromData data: Data) -> BlockHeader {
        return deserialize(fromByteStream: ByteStream(data))
    }

    static func deserialize(fromByteStream byteStream: ByteStream) -> BlockHeader {
        let blockHeader = BlockHeader()

        blockHeader.version = Int(byteStream.read(Int32.self))
        blockHeader.previousBlockHeaderHash = byteStream.read(Data.self, count: 32)
        blockHeader.merkleRoot = byteStream.read(Data.self, count: 32)
        blockHeader.timestamp = Int(byteStream.read(UInt32.self))
        blockHeader.bits = Int(byteStream.read(UInt32.self))
        blockHeader.nonce = Int(byteStream.read(UInt32.self))

        return blockHeader
    }

}
