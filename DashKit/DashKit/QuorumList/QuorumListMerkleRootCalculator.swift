import BitcoinCore

class QuorumListMerkleRootCalculator: IQuorumListMerkleRootCalculator {
    private let merkleRootCreator: IMerkleRootCreator

    init(merkleRootCreator: IMerkleRootCreator, quorumHasher: IDashHasher) {
        self.merkleRootCreator = merkleRootCreator
    }

    func calculateMerkleRoot(sortedQuorums: [Quorum]) -> Data? {
        return merkleRootCreator.create(hashes: sortedQuorums.map { $0.dataHash })
    }

}
