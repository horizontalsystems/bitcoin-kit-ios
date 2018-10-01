import Foundation

struct MerkleBlockMessage: IMessage {
    let maxBlockSize: UInt32

    let blockHeader: BlockHeader

    /// Number of transactions in the block (including unmatched ones)
    let totalTransactions: UInt32
    /// hashes in depth-first order (including standard varint size prefix)
    let numberOfHashes: VarInt
    let hashes: [Data]
    /// flag bits, packed per 8 in a byte, least significant bit first (including standard varint size prefix)
    let numberOfFlags: VarInt
    let flags: [UInt8]

    init(blockHeader: BlockHeader, totalTransactions: UInt32, numberOfHashes: VarInt, hashes: [Data], numberOfFlags: VarInt, flags: [UInt8], maxBlockSize: UInt32) {
        self.maxBlockSize = maxBlockSize
        self.blockHeader = blockHeader
        self.totalTransactions = totalTransactions
        self.numberOfHashes = numberOfHashes
        self.hashes = hashes
        self.numberOfFlags = numberOfFlags
        self.flags = flags
    }

    init(data: Data, network: NetworkProtocol) {
        maxBlockSize = network.maxBlockSize
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

    func getMerkleBlock() throws -> MerkleBlock {
        var matchedTxIds = [Data]()
        let merkleRoot = try getMerkleRootAndExtractTxids(matchedTxIds: &matchedTxIds)

        guard merkleRoot == blockHeader.merkleRoot else {
            throw ValidationError.wrongMerkleRoot
        }

        return MerkleBlock(header: blockHeader, transactionHashes: matchedTxIds, transactions: [Transaction]())
    }

}

extension MerkleBlockMessage: Equatable {

    static func ==(lhs: MerkleBlockMessage, rhs: MerkleBlockMessage) -> Bool {
        return lhs.serialized() == rhs.serialized()
    }

}

extension MerkleBlockMessage {

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

    static let bitMask: [UInt8] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

    /**
     * Extracts tx hashes that are in this merkle tree
     * and returns the merkle root of this tree.
     *
     * The returned root should be checked against the
     * merkle root contained in the block header for security.
     */
    private func getMerkleRootAndExtractTxids(matchedTxIds: inout [Data]) throws -> Data {
        // An empty set will not work
        guard totalTransactions > 0 else {
            throw ValidationError.noTransactions
        }

        // check for excessively high numbers of transactions
        guard totalTransactions <= maxBlockSize / 60 else { // 60 is the lower bound for the size of a serialized CTransaction
            throw ValidationError.tooManyTransactions
        }

        // there can never be more hashes provided than one for every txid
        guard hashes.count <= totalTransactions else {
            throw ValidationError.moreHashesThanTransactions
        }
        // there must be at least one bit per node in the partial tree, and at least one node per hash
        guard flags.count * 8 >= hashes.count else {
            throw ValidationError.matchedBitsFewerThanHashes
        }

        // calculate height of tree
        var height: UInt32 = 0
        while getTreeWidth(transactionCount: totalTransactions, height: height) > 1 {
            height = height + 1
        }

        // traverse the partial tree
        let used = ValuesUsed()
        let merkleRoot = try recursiveExtractHashes(matchedTxIds: &matchedTxIds, height: height, pos: 0, used: used)

        // verify that all bits were consumed (except for the padding caused by serializing it as a byte sequence)
        guard (used.bitsUsed + 7) / 8 == flags.count &&
                      // verify that all hashes were consumed
                      used.hashesUsed == hashes.count else {
            throw ValidationError.unnecessaryBits
        }


        return merkleRoot
    }

    // recursive function that traverses tree nodes, consuming the bits and hashes produced by TraverseAndBuild.
    // it returns the hash of the respective node.
    private func recursiveExtractHashes(matchedTxIds: inout [Data], height: UInt32, pos: UInt32, used: ValuesUsed) throws -> Data {
        guard used.bitsUsed < flags.count * 8 else {
            // overflowed the bits array - failure
            throw ValidationError.notEnoughBits
        }

        let parentOfMatch = checkBitLE(data: flags, index: used.bitsUsed)
        used.bitsUsed = used.bitsUsed + 1

        if (height == 0 || !parentOfMatch) {
            // if at height 0, or nothing interesting below, use stored hash and do not descend
            guard used.hashesUsed < hashes.count else {
                // overflowed the hash array - failure
                throw ValidationError.notEnoughHashes
            }

            let hash = hashes[used.hashesUsed]
            used.hashesUsed += 1
            if height == 0 && parentOfMatch {          // in case of height 0, we have a matched txid
                matchedTxIds.append(hash)
            }

            return hash
        } else {
            // otherwise, descend into the subtrees to extract matched txids and hashes
            let left = try recursiveExtractHashes(matchedTxIds: &matchedTxIds, height: height - 1, pos: pos * 2, used: used)
            var right = Data()

            if pos * 2 + 1 < getTreeWidth(transactionCount: totalTransactions, height: height - 1) {
                right = try recursiveExtractHashes(matchedTxIds: &matchedTxIds, height: height - 1, pos: pos * 2 + 1, used: used)
                guard left != right else {
                    throw ValidationError.duplicatedLeftOrRightBranches
                }
            } else {
                right = left
            }

            // and combine them before returning
            return combineLeftRight(left: left, right: right)
        }
    }

    private func combineLeftRight(left: Data, right: Data) -> Data {
        var result = Data()
        result.append(Data(left))
        result.append(Data(right))

        let hash = Crypto.sha256sha256(result)

        return Data(hash)
    }

    // helper function to efficiently calculate the number of nodes at given height in the merkle tree
    private func getTreeWidth(transactionCount: UInt32, height: UInt32) -> UInt32 {
        return (transactionCount + (1 << height) - 1) >> height
    }


    // Checks if the given bit is set in data, using little endian
    private func checkBitLE(data: [UInt8], index: Int) -> Bool {
        return (data[Int(index >> 3)] & MerkleBlockMessage.bitMask[Int(7 & index)]) != 0
    }

    private class ValuesUsed {
        var bitsUsed: Int = 0
        var hashesUsed: Int = 0
    }
}
