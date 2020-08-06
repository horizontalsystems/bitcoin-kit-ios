import UIExtensions

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

    var description: String {
        return "\(blockHeader.headerHash.reversedHex)"
    }

}

extension MerkleBlockMessage: Equatable {

    static func ==(lhs: MerkleBlockMessage, rhs: MerkleBlockMessage) -> Bool {
        return lhs.blockHeader.headerHash == rhs.blockHeader.headerHash &&
                lhs.totalTransactions == rhs.totalTransactions &&
                lhs.numberOfHashes.underlyingValue == rhs.numberOfHashes.underlyingValue &&
                lhs.hashes == rhs.hashes
    }

}
