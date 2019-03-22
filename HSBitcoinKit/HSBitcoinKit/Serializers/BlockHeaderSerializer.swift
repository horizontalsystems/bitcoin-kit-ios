import Foundation
import HSCryptoKit

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

    static func deserialize(byteStream: ByteStream) -> BlockHeader {
        let version = Int(byteStream.read(Int32.self))
        let previousBlockHeaderHash = byteStream.read(Data.self, count: 32)
        let merkleRoot = byteStream.read(Data.self, count: 32)
        let timestamp = Int(byteStream.read(UInt32.self))
        let bits = Int(byteStream.read(UInt32.self))
        let nonce = Int(byteStream.read(UInt32.self))

        return BlockHeader(
                version: version, previousBlockHeaderHash: previousBlockHeaderHash, merkleRoot: merkleRoot,
                timestamp: timestamp, bits: bits, nonce: nonce
        )
    }

}
