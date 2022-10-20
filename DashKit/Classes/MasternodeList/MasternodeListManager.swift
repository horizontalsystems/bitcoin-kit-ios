import BitcoinCore

class MasternodeListManager: IMasternodeListManager {

    private var storage: IDashStorage
    private let quorumListManager: IQuorumListManager
    private let masternodeListMerkleRootCalculator: IMasternodeListMerkleRootCalculator
    private let masternodeCbTxHasher: IMasternodeCbTxHasher
    private let masternodeSortedList: IMasternodeSortedList
    private let merkleBranch: IMerkleBranch

    var baseBlockHash: Data { return storage.masternodeListState?.baseBlockHash ?? Data(repeating: 0, count: 32) }

    init(storage: IDashStorage, quorumListManager: IQuorumListManager, masternodeListMerkleRootCalculator: IMasternodeListMerkleRootCalculator, masternodeCbTxHasher: IMasternodeCbTxHasher, merkleBranch: IMerkleBranch, masternodeSortedList: IMasternodeSortedList = MasternodeSortedList()) {
        self.storage = storage
        self.quorumListManager = quorumListManager
        self.masternodeListMerkleRootCalculator = masternodeListMerkleRootCalculator
        self.masternodeCbTxHasher = masternodeCbTxHasher
        self.merkleBranch = merkleBranch
        self.masternodeSortedList = masternodeSortedList
    }

    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws {
        masternodeSortedList.removeAll()

        //01.Create a copy of the masternode list which was valid at “baseBlockHash”. If “baseBlockHash” is all-zero, an empty list must be used.
        masternodeSortedList.add(masternodes: storage.masternodes)
        //02.Delete all entries found in “deletedMNs” from this list. Please note that “deletedMNs” contains the ProRegTx hashes of the masternodes and NOT the hashes of the SML entries.
        masternodeSortedList.remove(by: masternodeListDiffMessage.deletedMNs)
        //03.Add or replace all entries found in “mnList” in the list
        masternodeSortedList.add(masternodes: masternodeListDiffMessage.mnList)
        //04.Calculate the merkle root of the list by following the “Calculating the merkle root of the Masternode list” section
        let hash = masternodeListMerkleRootCalculator.calculateMerkleRoot(sortedMasternodes: masternodeSortedList.masternodes)

        //05.Compare the calculated merkle root with what is found in “cbTx”. If it does not match, abort the process and ask for diffs from another node.
        guard masternodeListDiffMessage.cbTx.merkleRootMNList == hash else {
            throw DashKitErrors.MasternodeListValidation.wrongMerkleRootList
        }
        //06.Calculate the hash of “cbTx” and verify existence of this transaction in the block specified by “blockHash”. To do this, use the already received block header and the fields “totalTransactions”, “merkleHashes” and “merkleFlags” from the MNLISTDIFF message and perform a merkle verification the same way as done when a “MERKLEBLOCK” message is received. If the verification fails, abort the process and ask for diffs from another node.
        let cbTxHash = masternodeCbTxHasher.hash(coinbaseTransaction: masternodeListDiffMessage.cbTx)

        let calculatedMerkleRootData = try merkleBranch.calculateMerkleRoot(txCount: Int(masternodeListDiffMessage.totalTransactions), hashes: masternodeListDiffMessage.merkleHashes, flags: [UInt8](masternodeListDiffMessage.merkleFlags))

        guard calculatedMerkleRootData.matchedHashes.contains(cbTxHash) else {
            throw DashKitErrors.MasternodeListValidation.wrongCoinbaseHash
        }

        guard let block = storage.block(byHash: masternodeListDiffMessage.blockHash) else {
            throw DashKitErrors.MasternodeListValidation.noMerkleBlockHeader
        }

        guard block.merkleRoot == calculatedMerkleRootData.merkleRoot else {
            throw DashKitErrors.MasternodeListValidation.wrongMerkleRoot
        }
        //07.Validate and store llmq quorums
        try quorumListManager.updateList(masternodeListDiffMessage: masternodeListDiffMessage)

        //08.Store the resulting validated masternode list identified by “blockHash”
        storage.masternodes = masternodeSortedList.masternodes
        storage.masternodeListState = MasternodeListState(baseBlockHash: masternodeListDiffMessage.blockHash)
        // todo: Can optimize. Update only difference of masternode list
    }

}
