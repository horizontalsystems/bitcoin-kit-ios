import Foundation
import HSCryptoKit

class MerkleBlockValidator: IMerkleBlockValidator {

    enum ValidationError: Error {
        case wrongMerkleRoot
        case noTransactions
        case tooManyTransactions
        case moreHashesThanTransactions
        case matchedBitsFewerThanHashes
        case unnecessaryBits
        case notEnoughBits
        case notEnoughHashes
        case duplicatedLeftOrRightBranches
    }

    private let maxBlockSize: UInt32
    private let merkleBranch: IMerkleBranch

    init(maxBlockSize: UInt32, merkleBranch: IMerkleBranch) {
        self.maxBlockSize = maxBlockSize
        self.merkleBranch = merkleBranch
    }

    func merkleBlock(from message: MerkleBlockMessage) throws -> MerkleBlock {
        // An empty set will not work
        guard message.totalTransactions > 0 else {
            throw MerkleBlockValidator.ValidationError.noTransactions
        }

        // check for excessively high numbers of transactions
        guard message.totalTransactions <= maxBlockSize / 60 else { // 60 is the lower bound for the size of a serialized CTransaction
            throw MerkleBlockValidator.ValidationError.tooManyTransactions
        }

        // there can never be more hashes provided than one for every txid
        guard message.hashes.count <= message.totalTransactions else {
            throw MerkleBlockValidator.ValidationError.moreHashesThanTransactions
        }
        // there must be at least one bit per node in the partial tree, and at least one node per hash
        guard message.flags.count * 8 >= message.hashes.count else {
            throw MerkleBlockValidator.ValidationError.matchedBitsFewerThanHashes
        }

        let merkleRootData = try merkleBranch.calculateMerkleRoot(txCount: Int(message.totalTransactions), hashes: message.hashes, flags: message.flags)

        guard merkleRootData.merkleRoot == message.blockHeader.merkleRoot else {
            throw ValidationError.wrongMerkleRoot
        }

        return MerkleBlock(header: message.blockHeader, transactionHashes: merkleRootData.matchedHashes, transactions: [FullTransaction]())
    }

}
