import BigInt
import BitcoinCore

// BitcoinCore Compatibility

protocol IDashDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

protocol IDashHasher {
    func hash(data: Data) -> Data
}

protocol IDashBlockValidatorHelper {
    func previous(for block: Block, count: Int) -> Block?
}

protocol IDashTransactionSizeCalculator {
    func transactionSize(previousOutputs: [Output], outputScriptTypes: [ScriptType]) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
}

protocol IDashTransactionSyncer {
    func handleRelayed(transactions: [FullTransaction])
}

protocol IDashPeer: IPeer {
    var delegate: PeerDelegate? { get set }
    var localBestBlockHeight: Int32 { get set }
    var announcedLastBlockHeight: Int32 { get }
    var host: String { get }
    var logName: String { get }
    var ready: Bool { get }
    var connected: Bool { get }
    var synced: Bool { get set }
    var blockHashesSynced: Bool { get set }
    func connect()
    func disconnect(error: Error?)
    func add(task: PeerTask)
    func filterLoad(bloomFilter: BloomFilter)
    func sendMempoolMessage()
    func sendPing(nonce: UInt64)
    func equalTo(_ peer: IPeer?) -> Bool
}

// ###############################

public protocol DashKitDelegate: class {
    func transactionsUpdated(inserted: [DashTransactionInfo], updated: [DashTransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: BalanceInfo)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
    func kitStateUpdated(state: BitcoinCore.KitState)
}

protocol IPeerTaskFactory {
    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask
}

protocol IMasternodeListManager {
    var baseBlockHash: Data { get }
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
}

protocol IQuorumListManager {
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
    func quorum(for requestID: Data, type: QuorumType) throws -> Quorum
}

protocol IMasternodeListSyncer {
}

protocol IDashStorage {
    var masternodes: [Masternode] { get set }
    var quorums: [Quorum] { get set }
    var masternodeListState: MasternodeListState? { get set }

    func quorums(by type: QuorumType) -> [Quorum]
    func inputs(transactionHash: Data) -> [Input]

    func instantTransactionHashes() -> [Data]
    func add(instantTransactionHash: Data)

    func add(instantTransactionInput: InstantTransactionInput)
    func removeInstantTransactionInputs(for txHash: Data)
    func instantTransactionInputs(for txHash: Data) -> [InstantTransactionInput]
    func instantTransactionInput(for inputTxHash: Data) -> InstantTransactionInput?

    var lastBlock: Block? { get }
    func block(byHash: Data) -> Block?

    func unspentOutputs() -> [UnspentOutput]

    func transactionExists(byHash: Data) -> Bool
    func transactionFullInfo(byHash hash: Data) -> FullTransactionForInfo?
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

protocol IQuorumSortedList {
    var quorums: [Quorum] { get }

    func add(quorums: [Quorum])
    func removeAll()
    func remove(quorums: [Quorum])
    func remove(by pairs: [(type: UInt8, quorumHash: Data)])
}

protocol IMasternodeListMerkleRootCalculator {
    func calculateMerkleRoot(sortedMasternodes: [Masternode]) -> Data?
}

protocol IQuorumListMerkleRootCalculator {
    func calculateMerkleRoot(sortedQuorums: [Quorum]) -> Data?
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
    func instantTransactionInputs(for txHash: Data, instantTransaction: FullTransaction?) -> [InstantTransactionInput]
    func updateInput(for inputTxHash: Data, transactionInputs: [InstantTransactionInput]) throws
    func isTransactionInstant(txHash: Data) -> Bool
    func isTransactionExists(txHash: Data) -> Bool
    func makeInstant(txHash: Data)
}

public protocol IInstantTransactionDelegate: class {
    func onUpdateInstant(transactionHash: Data)
}

protocol IInstantTransactionState {
    var instantTransactionHashes: [Data] { get set }
    func append(_ hash: Data)
}

protocol IMasternodeParser {
    func parse(byteStream: ByteStream) -> Masternode
}

protocol IQuorumParser {
    func parse(byteStream: ByteStream) -> Quorum
}

protocol ITransactionLockVoteHandler {
    func handle(transaction: FullTransaction)
    func handle(lockVote: TransactionLockVoteMessage)
}

protocol IInstantSendLockHandler {
    func handle(transactionHash: Data)
    func handle(isLock: ISLockMessage)
}

protocol ITransactionLockVoteValidator {
    func validate(lockVote: TransactionLockVoteMessage) throws
}

protocol ITransactionLockVoteManager {
    var relayedLockVotes: Set<TransactionLockVoteMessage> { get }
    var checkedLockVotes: Set<TransactionLockVoteMessage> { get }
    func processed(lvHash: Data) -> Bool
    func add(relayed: TransactionLockVoteMessage)
    func add(checked: TransactionLockVoteMessage)

    func takeRelayedLockVotes(for txHash: Data) -> [TransactionLockVoteMessage]

    func validate(lockVote: TransactionLockVoteMessage) throws
}

protocol IInstantSendLockValidator {
    func validate(isLock: ISLockMessage) throws
}

protocol IInstantSendLockManager {
    var relayedLocks: [Data: ISLockMessage] { get }
    func add(relayed: ISLockMessage)

    func takeRelayedLock(for txHash: Data) -> ISLockMessage?

    func validate(isLock: ISLockMessage) throws
}


