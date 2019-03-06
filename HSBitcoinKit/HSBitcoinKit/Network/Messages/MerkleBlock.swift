import Foundation
import HSCryptoKit

class MerkleBlock {
    let header: BlockHeader
    let transactionHashes: [Data]
    var height: Int? = nil
    var transactions: [Transaction]

    lazy var headerHash: Data = {
        return self.header.headerHash
    }()

    lazy var reversedHeaderHashHex: String = {
        return self.header.headerHash.reversedHex
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
