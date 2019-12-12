import BitcoinCore

//01. Create a copy of the active LLMQ sets which were given at "baseBlockHash". If “baseBlockHash” is all-zero, empty sets must be used.
//02. Delete all entries found in "deletedQuorums" from the corresponding active LLMQ sets.
//03. Verify each final commitment found in "newQuorums", by the same rules found in DIP6 - Long-Living Masternode Quorums. If any final commitment is invalid, abort the process and ask for diffs from another node.
//04. Add the LLMQ defined by the final commitments found in "newQuorums" to the corresponding active LLMQ sets.
//05. Calculate the merkle root of the active LLMQ sets by following the “Calculating the merkle root of the active LLMQs” section
//06. Compare the calculated merkle root with what is found in “cbTx”. If it does not match, abort the process and ask for diffs from another node.
//07. Store the new active LLMQ sets the same way the masternode list is stored.

class QuorumListManager: IQuorumListManager {

    private var storage: IDashStorage
    private let hasher: IDashHasher
    private let quorumListMerkleRootCalculator: IQuorumListMerkleRootCalculator
    private let quorumSortedList: IQuorumSortedList
    private let merkleBranch: IMerkleBranch

    init(storage: IDashStorage, hasher: IDashHasher, quorumListMerkleRootCalculator: IQuorumListMerkleRootCalculator, merkleBranch: IMerkleBranch, quorumSortedList: IQuorumSortedList = QuorumSortedList()) {
        self.storage = storage
        self.hasher = hasher
        self.quorumListMerkleRootCalculator = quorumListMerkleRootCalculator
        self.merkleBranch = merkleBranch
        self.quorumSortedList = quorumSortedList
    }

    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws {
        if let merkleRootQuorums = masternodeListDiffMessage.cbTx.merkleRootQuorums {
            quorumSortedList.removeAll()

            //01.
            quorumSortedList.add(quorums: storage.quorums)
            //02.
            quorumSortedList.remove(by: masternodeListDiffMessage.deletedQuorums)
            //03.
            quorumSortedList.add(quorums: masternodeListDiffMessage.quorumList)
            //04.
            let sortedQuorums = quorumSortedList.quorums
            //05.
            let hash = quorumListMerkleRootCalculator.calculateMerkleRoot(sortedQuorums: sortedQuorums)

            //.06
            guard merkleRootQuorums == hash else {
                throw DashKitErrors.QuorumListValidation.wrongMerkleRootList
            }
            //.07
            storage.quorums = sortedQuorums
        }
    }

    func quorum(for requestID: Data, type: QuorumType) throws -> Quorum {
        let typedQuorums = storage.quorums(by: type)

        guard !typedQuorums.isEmpty else {
            throw DashKitErrors.ISLockValidation.quorumNotFound
        }

        var quorum = typedQuorums[0]
        var lowestHash = orderingHash(quorum: quorum, requestID: requestID)

        for index in 1..<typedQuorums.count {
            let currentOrderingHash = orderingHash(quorum: typedQuorums[index], requestID: requestID)
            if currentOrderingHash < lowestHash {
                lowestHash = currentOrderingHash
                quorum = typedQuorums[index]
            }
        }

        return quorum
    }

    private func orderingHash(quorum: Quorum, requestID: Data) -> Data {
        return hasher.hash(data: quorum.typeWithQuorumHash + requestID)
    }

}
