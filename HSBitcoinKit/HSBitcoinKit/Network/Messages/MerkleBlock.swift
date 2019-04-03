import Foundation
import HSCryptoKit

class MerkleBlock {
    let header: BlockHeader
    let transactionHashes: [Data]
    var height: Int? = nil
    var transactions: [FullTransaction]

    lazy var headerHash: Data = {
        return self.header.headerHash
    }()

    lazy var headerHashReversedHex: String = {
        return self.headerHash.reversedHex
    }()

    var complete: Bool {
        return transactionHashes.count == transactions.count
    }

    init(header: BlockHeader, transactionHashes: [Data], transactions: [FullTransaction]) {
        self.header = header
        self.transactionHashes = transactionHashes
        self.transactions = transactions
    }
}
