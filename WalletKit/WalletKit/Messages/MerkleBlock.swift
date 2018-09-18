import Foundation

class MerkleBlock {
    let header: BlockHeader
    let transactionHashes: [Data]
    var transactions: [Transaction]

    var headerHash: Data {
        return Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: header))
    }

    var complete: Bool {
        return transactionHashes.count == transactions.count
    }

    init(header: BlockHeader, transactionHashes: [Data], transactions: [Transaction]) {
        self.header = header
        self.transactionHashes = transactionHashes
        self.transactions = transactions
    }
}
