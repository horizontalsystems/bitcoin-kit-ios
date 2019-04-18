public class MerkleBranch: IMerkleBranch {
    static let bitMask: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

    private let hasher: IHasher
    private var txCount: Int = 0
    private var hashes = [Data]()
    private var flags = [UInt8]()

    private var bitsUsed = 0
    private var hashesUsed = 0

    public init(hasher: IHasher) {
        self.hasher = hasher
    }

    public func calculateMerkleRoot(txCount: Int, hashes: [Data], flags: [UInt8]) throws -> (merkleRoot: Data, matchedHashes: [Data]) {
        self.txCount = txCount
        self.hashes = hashes
        self.flags = flags

        var matchedHashes = [Data]()

        bitsUsed = 0
        hashesUsed = 0
        //
        // Start at the root and travel down to the leaf node
        //
        var height = 0
        while getTreeWidth(height) > 1 {
            height += 1
        }
        let merkleRoot = try parseBranch(height: height, pos: 0, matchedHashes: &matchedHashes)
        //
        // Verify that all bits and hashes were consumed
        //
        if (bitsUsed + 7) / 8 != flags.count {
            throw BitcoinCoreErrors.MerkleBlockValidation.unnecessaryBits
        }
        return (merkleRoot: merkleRoot, matchedHashes: matchedHashes)
    }

    private func parseBranch(height: Int, pos: Int, matchedHashes: inout [Data]) throws -> Data {
        if bitsUsed >= flags.count * 8 {
            throw BitcoinCoreErrors.MerkleBlockValidation.notEnoughBits
        }
        bitsUsed += 1
        let parentOfMatch = checkBitLE(data: flags, index: bitsUsed - 1)
        if height == 0 || !parentOfMatch {
            //
            // If at height 0 or nothing interesting below, use the stored hash and do not descend
            // to the next level.  If we have a match at height 0, it is a matching transaction.
            //
            guard hashesUsed < hashes.count else {
                // overflowed the hash array - failure
                throw BitcoinCoreErrors.MerkleBlockValidation.notEnoughHashes
            }
            if height == 0, parentOfMatch {
                matchedHashes.append(hashes[hashesUsed])
            }
            hashesUsed += 1
            return hashes[hashesUsed - 1]
        }
        //
        // Continue down to the next level
        //
        let right: Data
        let left = try parseBranch(height: height - 1, pos: pos * 2, matchedHashes: &matchedHashes)
        if pos * 2 + 1 < getTreeWidth(height - 1) {
            right = try parseBranch(height: height - 1, pos: pos * 2 + 1, matchedHashes: &matchedHashes)
        } else {
            right = left
        }

        return hasher.hash(data: left + right)
    }


    // Checks if the given bit is set in data, using little endian
    private func checkBitLE(data: [UInt8], index: Int) -> Bool {
        return (data[Int(index >> 3)] & MerkleBranch.bitMask[Int(7 & index)]) != 0
    }

    private func getTreeWidth(_ height: Int) -> Int {
        return (txCount + (1 << height) - 1) >> height
    }

}

