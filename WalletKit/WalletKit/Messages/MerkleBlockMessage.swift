import Foundation

struct MerkleBlockMessage: IMessage {
    let blockHeader: BlockHeader

    /// Number of transactions in the block (including unmatched ones)
    let totalTransactions: UInt32
    /// hashes in depth-first order (including standard varint size prefix)
    let numberOfHashes: VarInt
    let hashes: [Data]
    /// flag bits, packed per 8 in a byte, least significant bit first (including standard varint size prefix)
    let numberOfFlags: VarInt
    let flags: [UInt8]

    init(blockHeader: BlockHeader, totalTransactions: UInt32, numberOfHashes: VarInt, hashes: [Data], numberOfFlags: VarInt, flags: [UInt8]) {
        self.blockHeader = blockHeader
        self.totalTransactions = totalTransactions
        self.numberOfHashes = numberOfHashes
        self.hashes = hashes
        self.numberOfFlags = numberOfFlags
        self.flags = flags
    }

    init(data: Data) {
        let byteStream = ByteStream(data)

        blockHeader = BlockHeaderSerializer.deserialize(byteStream: byteStream)
        totalTransactions = byteStream.read(UInt32.self)
        numberOfHashes = byteStream.read(VarInt.self)

        var hashes = [Data]()
        for _ in 0..<numberOfHashes.underlyingValue {
            hashes.append(byteStream.read(Data.self, count: 32))
        }

        self.hashes = hashes
        numberOfFlags = byteStream.read(VarInt.self)

        var flags = [UInt8]()
        for _ in 0..<numberOfFlags.underlyingValue {
            flags.append(byteStream.read(UInt8.self))
        }

        self.flags = flags
    }

    func serialized() -> Data {
        var data = Data()
        data += BlockHeaderSerializer.serialize(header: blockHeader)
        data += totalTransactions
        data += numberOfHashes.serialized()
        data += hashes.flatMap { $0 }
        data += numberOfFlags.serialized()
        data += flags
        return data
    }

}

extension MerkleBlockMessage: Equatable {

    static func ==(lhs: MerkleBlockMessage, rhs: MerkleBlockMessage) -> Bool {
        return lhs.serialized() == rhs.serialized()
    }

}