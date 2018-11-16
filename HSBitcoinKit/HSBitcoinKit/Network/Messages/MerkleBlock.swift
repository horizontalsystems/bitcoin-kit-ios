import Foundation
import HSCryptoKit

class MerkleBlock {
    let header: BlockHeader
    let transactionHashes: [Data]
    var height: Int? = nil
    var transactions: [Transaction]

    lazy var headerHash: Data = {
        return CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: header))
    }()
    lazy var reversedHeaderHashHex: String = {
        return self.headerHash.reversedHex
    }()

    var complete: Bool {
        return transactionHashes.count == transactions.count
    }

    init(header: BlockHeader, transactionHashes: [Data], transactions: [Transaction]) {
        self.header = header
        self.transactionHashes = transactionHashes
        self.transactions = transactions
    }
}
