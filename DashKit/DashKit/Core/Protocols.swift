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
    func transactionSize(inputs: [ScriptType], outputScriptTypes: [ScriptType]) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
}

protocol IDashTransactionSyncer {
    func handle(transactions: [FullTransaction])
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

protocol IPeerTaskFactory {
    func createRequestMasternodeListDiffTask(baseBlockHash: Data, blockHash: Data) -> PeerTask
}

protocol IMasternodeListManager {
    var baseBlockHash: Data { get }
    func updateList(masternodeListDiffMessage: MasternodeListDiffMessage) throws
}

protocol IMasternodeListSyncer {
}

protocol IDashStorage {
    var masternodes: [Masternode] { get set }
    var masternodeListState: MasternodeListState? { get set }

    func inputs(transactionHash: Data) -> [Input]

    func instantTransactionInputs(for txHash: Data) -> [InstantTransactionInput]
    func instantTransactionInput(for inputTxHash: Data) -> InstantTransactionInput?
    func add(instantTransactionInput: InstantTransactionInput)

    func block(byHash: Data) -> Block?
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
    func instantTransactionInputs(for txHash: Data, instantTransaction: FullTransaction?) -> [InstantTransactionInput]
    func increaseVoteCount(for inputTxHash: Data)
    func isTransactionInstant(txHash: Data) -> Bool
}

protocol IMasternodeParser {
    func parse(byteStream: ByteStream) -> Masternode
}

protocol ITransactionLockVoteValidator {
    func validate(quorumModifierHash: Data, masternodeProTxHash: Data) throws
}

protocol ITransactionLockVoteManager {
    func takeRelayedLockVotes(for txHash: Data) -> [TransactionLockVoteMessage]
    func add(relayed: TransactionLockVoteMessage)
    func inRelayed(lvHash: Data) -> Bool

    func add(checked: TransactionLockVoteMessage)
    func removeCheckedLockVotes(for txHash: Data)
    func inChecked(lvHash: Data) -> Bool

    func validate(lockVote: TransactionLockVoteMessage) throws
}

