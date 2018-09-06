import Foundation

struct MerkleBlock {
    let header: BlockHeader
    let transactionHashes: [Data]
    var transactions: [Transaction]

    var headerHash: Data {
        return Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: header))
    }
}
