import Foundation
import HSCryptoKit

struct MerkleBlockMessage: IMessage {
    let command: String = "merkleblock"

    let blockHeader: BlockHeader

    /// Number of transactions in the block (including unmatched ones)
    let totalTransactions: UInt32
    /// hashes in depth-first order (including standard varint size prefix)
    let numberOfHashes: VarInt
    let hashes: [Data]
    /// flag bits, packed per 8 in a byte, least significant bit first (including standard varint size prefix)
    let numberOfFlags: VarInt
    let flags: [UInt8]

}

extension MerkleBlockMessage: Equatable {

    static func ==(lhs: MerkleBlockMessage, rhs: MerkleBlockMessage) -> Bool {
        return lhs.blockHeader.headerHash == rhs.blockHeader.headerHash &&
                lhs.totalTransactions == rhs.totalTransactions &&
                lhs.numberOfHashes.underlyingValue == rhs.numberOfHashes.underlyingValue &&
                lhs.hashes == rhs.hashes
    }

}
