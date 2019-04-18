import BitcoinCore

protocol IPeerTaskFactory {
    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask
}

protocol IMasternodeListManager {
    var baseBlockHash: Data { get }
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
}

protocol IMasternodeListSyncer {
    func sync(blockHash: Data)
}

protocol IDashStorage: IStorage {
    var masternodes: [Masternode] { get set }
    var masternodeListState: MasternodeListState? { get set }

    func instantTransactionInput(for inputTxHash: Data) -> InstantTransactionInput?
    func instantTransactionInputs(for txHash: Data) -> [InstantTransactionInput]
    func add(instantTransactionInput: InstantTransactionInput)
}

protocol IInstantSendFactory {
    func instantTransactionInput(txHash: Data, inputTxHash: Data, voteCount: Int, blockHeight: Int?) -> InstantTransactionInput
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

protocol IInstantTransactionManager {
    func handle(transactions: [FullTransaction])
    func handle(lockVote: TransactionLockVoteMessage) throws
}

protocol IMasternodeParser {
    func parse(byteStream: ByteStream) -> Masternode
}

protocol ITransactionLockVoteValidator {
    func validate(quorumModifierHash: Data, masternodeProTxHash: Data) throws
}