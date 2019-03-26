protocol IPeerTaskFactory {
    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask
}

protocol IMasternodeListManager {
    var baseBlockHash: Data { get }
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
}

protocol IMasternodeListSyncer {

}

protocol IDashStorage: IStorage {
    var masternodes: [Masternode] { get set }
    var masternodeListState: MasternodeListState? { get set }
}

protocol IMasternodeSortedList {
    var masternodes: [Masternode] { get }

    func add(masternodes: [Masternode])
    func removeAll()
    func remove(masternodes: [Masternode])
    func remove(by proRegTxHashes: [Data])
}

protocol IMasternodeListMerkleRootCalculator {
    func calculateMerkleRoot(sortedMasternodes: [Masternode]) -> Data?
}

protocol IMasternodeCbTxHasher {
    func hash(coinbaseTransaction: CoinbaseTransaction) -> Data
}

protocol IMasternodeSerializer {
    func serialize(masternode: Masternode) -> Data
}

protocol ICoinbaseTransactionSerializer {
    func serialize(coinbaseTransaction: CoinbaseTransaction) -> Data
}

protocol IMerkleRootCreator {
    func create(hashes: [Data]) -> Data?
}

protocol IHasher {
    func hash(data: Data) -> Data
}

protocol IMerkleHasher {
    func hash(left: Data, right: Data) -> Data
}