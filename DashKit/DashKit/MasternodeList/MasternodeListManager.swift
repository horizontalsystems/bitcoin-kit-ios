import BitcoinCore

//01. Create a copy of the masternode list which was valid at “baseBlockHash”. If “baseBlockHash” is all-zero, an empty list must be used.
//02. Delete all entries found in “deletedMNs” from this list. Please note that “deletedMNs” contains the ProRegTx hashes of the masternodes and NOT the hashes of the SML entries.
//03. Add or replace all entries found in “mnList” in the list
//04. Calculate the merkle root of the list by following the “Calculating the merkle root of the Masternode list” section
//05. Compare the calculated merkle root with what is found in “cbTx”. If it does not match, abort the process and ask for diffs from another node.
//06. Calculate the hash of “cbTx” and verify existence of this transaction in the block specified by “blockHash”. To do this, use the already received block header and the fields “totalTransactions”, “merkleHashes” and “merkleFlags” from the MNLISTDIFF message and perform a merkle verification the same way as done when a “MERKLEBLOCK” message is received. If the verification fails, abort the process and ask for diffs from another node.
//07. Store the resulting validated masternode list identified by “blockHash”

class MasternodeListManager: IMasternodeListManager {

    enum ValidationError: Error {
        case wrongMerkleRootList
        case wrongCoinbaseHash
        case noMerkleBlockHeader
        case wrongMerkleRoot
    }

    private var storage: IDashStorage
    private let masternodeListMerkleRootCalculator: IMasternodeListMerkleRootCalculator
    private let masternodeCbTxHasher: IMasternodeCbTxHasher
    private let masternodeSortedList: IMasternodeSortedList
    private let merkleBranch: IMerkleBranch

    var baseBlockHash: Data { return storage.masternodeListState?.baseBlockHash ?? Data(repeating: 0, count: 32) }

    init(storage: IDashStorage, masternodeListMerkleRootCalculator: IMasternodeListMerkleRootCalculator, masternodeCbTxHasher: IMasternodeCbTxHasher, merkleBranch: IMerkleBranch, masternodeSortedList: IMasternodeSortedList = MasternodeSortedList()) {
        self.storage = storage
        self.masternodeListMerkleRootCalculator = masternodeListMerkleRootCalculator
        self.masternodeCbTxHasher = masternodeCbTxHasher
        self.merkleBranch = merkleBranch
        self.masternodeSortedList = masternodeSortedList
    }

    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws {
        masternodeSortedList.removeAll()

        //01.
        masternodeSortedList.add(masternodes: storage.masternodes)
        //02.
        masternodeSortedList.remove(by: masternodeListDiffMessage.deletedMNs)
        //03.
        masternodeSortedList.add(masternodes: masternodeListDiffMessage.mnList)
        //04.
        let hash = masternodeListMerkleRootCalculator.calculateMerkleRoot(sortedMasternodes: masternodeSortedList.masternodes)

        //05.
        guard masternodeListDiffMessage.cbTx.merkleRootMNList == hash else {
            throw ValidationError.wrongMerkleRootList
        }
        //06.
        let cbTxHash = masternodeCbTxHasher.hash(coinbaseTransaction: masternodeListDiffMessage.cbTx)

        let calculatedMerkleRootData = try merkleBranch.calculateMerkleRoot(txCount: Int(masternodeListDiffMessage.totalTransactions), hashes: masternodeListDiffMessage.merkleHashes, flags: [UInt8](masternodeListDiffMessage.merkleFlags))

        guard calculatedMerkleRootData.matchedHashes.contains(cbTxHash) else {
            throw ValidationError.wrongCoinbaseHash
        }

        guard let block = storage.block(byHashHex: masternodeListDiffMessage.blockHash.reversedHex) else {
            throw ValidationError.noMerkleBlockHeader
        }

        guard block.merkleRoot == calculatedMerkleRootData.merkleRoot else {
            throw ValidationError.wrongMerkleRoot
        }
        //07.
        storage.masternodeListState = MasternodeListState(baseBlockHash: masternodeListDiffMessage.blockHash)
        storage.masternodes = masternodeSortedList.masternodes
        // todo: Can optimize. Update only difference of masternode list
    }

}
