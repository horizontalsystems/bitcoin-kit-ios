import BigInt
import RxSwift
import Alamofire
import HSCryptoKit

enum BlockValidatorType { case header, bits, legacy, testNet, EDA, DAA, DGW }

public protocol IDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

public protocol IBlockValidatorHelper {
    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

public protocol IBlockValidator: class {
    func validate(block: Block, previousBlock: Block) throws
    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool
}

protocol IBlockValidatorFactory {
    func validator(for validatorType: BlockValidatorType) -> IBlockValidator
}

protocol IHDWallet {
    var gapLimit: Int { get }
    func publicKey(account: Int, index: Int, external: Bool) throws -> PublicKey
    func privateKeyData(account: Int, index: Int, external: Bool) throws -> Data
}

protocol IApiConfigProvider {
    var reachabilityHost: String { get }
    var apiUrl: String { get }
}

protocol IReachabilityManager {
    var isReachable: Bool { get }
    var reachabilitySignal: Signal { get }
}

protocol IPeerAddressManager: class {
    var delegate: IPeerAddressManagerDelegate? { get set }
    var ip: String? { get }
    var hasFreshIps: Bool { get }
    func markSuccess(ip: String)
    func markFailed(ip: String)
    func add(ips: [String])
    func markConnected(peer: IPeer)
}

protocol IStateManager {
    var restored: Bool { get set }
}

protocol IBlockDiscovery {
    func discoverBlockHashes(account: Int, external: Bool) -> Observable<([PublicKey], [BlockHash])>
}

public protocol IStorage {
    var initialRestored: Bool? { get }
    func set(initialRestored: Bool)

    func leastScoreFastestPeerAddress(excludingIps: [String]) -> PeerAddress?
    func save(peerAddresses: [PeerAddress])
    func increasePeerAddressScore(ip: String)
    func deletePeerAddress(byIp ip: String)
    func set(connectionTime: Double, toPeerAddress: String)


    var blockchainBlockHashes: [BlockHash] { get }
    var lastBlockchainBlockHash: BlockHash? { get }
    func blockHashHeaderHashes(except: Data) -> [String]
    var blockHashHeaderHashes: [Data] { get }
    var lastBlockHash: BlockHash? { get }
    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash]
    func add(blockHashes: [BlockHash])
    func deleteBlockHash(byHash: Data)
    func deleteBlockchainBlockHashes()
    func deleteUselessBlocks(before: Int)
    func releaseMemory()

    var blocksCount: Int { get }
    var lastBlock: Block? { get }
    func blocksCount(headerHashes: [Data]) -> Int
    func update(block: Block)
    func save(block: Block)
    func blocks(heightGreaterThan: Int, sortedBy: Block.Columns, limit: Int) -> [Block]
    func blocks(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Block]
    func blocks(byHexes: [String]) -> [Block]
    func blocks(heightGreaterThanOrEqualTo: Int, stale: Bool) -> [Block]
    func blocks(stale: Bool) -> [Block]
    func block(byHeight: Int) -> Block?
    func block(byHash: Data) -> Block?
    func block(stale: Bool, sortedHeight: String) -> Block?
    func add(block: Block) throws
    func delete(blocks: [Block]) throws
    func unstaleAllBlocks() throws
    func timestamps(from startHeight: Int, to endHeight: Int) -> [Int]

    func transactionExists(byHash: Data) -> Bool
    func transaction(byHash: Data) -> Transaction?
    func transactions(ofBlock: Block) -> [Transaction]
    func newTransactions() -> [Transaction]
    func newTransaction(byHash: Data) -> Transaction?
    func relayedTransactionExists(byHash: Data) -> Bool
    func add(transaction: FullTransaction) throws
    func update(transaction: Transaction) throws
    func fullInfo(forTransactions: [TransactionWithBlock]) -> [FullTransactionForInfo]
    func fullTransactionsInfo(fromTimestamp: Int?, fromOrder: Int?, limit: Int?) -> [FullTransactionForInfo]
    func fullTransactionInfo(byHash hash: Data) -> FullTransactionForInfo?

    func outputsWithPublicKeys() -> [OutputWithPublicKey]
    func unspentOutputs() -> [UnspentOutput]
    func inputs(transactionHash: Data) -> [Input]
    func outputs(transactionHash: Data) -> [Output]
    func previousOutput(ofInput: Input) -> Output?

    func sentTransaction(byHash: Data) -> SentTransaction?
    func update(sentTransaction: SentTransaction)
    func delete(sentTransaction: SentTransaction)
    func add(sentTransaction: SentTransaction)

    func publicKeys() -> [PublicKey]
    func publicKey(byScriptHashForP2WPKH: Data) -> PublicKey?
    func publicKey(byRawOrKeyHash: Data) -> PublicKey?
    func add(publicKeys: [PublicKey])
    func publicKeysWithUsedState() -> [PublicKeyWithUsedState]
    func publicKey(byPath: String) -> PublicKey?
    func invalidate(transaction: Transaction, transactionInfo: TransactionInfo) throws
}

public protocol IRestoreKeyConverter {
    func keysForApiRestore(publicKey: PublicKey) -> [String]
    func bloomFilterElements(publicKey: PublicKey) -> [Data]
}

public protocol IPublicKeyManager {
    func changePublicKey() throws -> PublicKey
    func receivePublicKey() throws -> PublicKey
    func fillGap() throws
    func addKeys(keys: [PublicKey])
    func gapShifts() -> Bool
    func publicKey(byPath: String) throws -> PublicKey
}

public protocol IBloomFilterManagerDelegate: class {
    func bloomFilterUpdated(bloomFilter: BloomFilter)
}

public protocol IBloomFilterManager: AnyObject {
    var delegate: IBloomFilterManagerDelegate? { get set }
    var bloomFilter: BloomFilter? { get }
    func regenerateBloomFilter()
}


public protocol IPeerGroup: class {
    var observable: Observable<PeerGroupEvent> { get }

    func start()
    func stop()

    func isReady(peer: IPeer) -> Bool
}

protocol IPeerManager: class {
    func add(peer: IPeer)
    func peerDisconnected(peer: IPeer)
    func disconnectAll()
    func totalPeersCount() -> Int
    func connected() -> [IPeer]
    func sorted() -> [IPeer]
}

public protocol IPeer: class {
    var delegate: PeerDelegate? { get set }
    var localBestBlockHeight: Int32 { get set }
    var announcedLastBlockHeight: Int32 { get }
    var host: String { get }
    var logName: String { get }
    var ready: Bool { get }
    var connected: Bool { get }
    var connectionTime: Double { get }
    var tasks: [PeerTask] { get }
    func connect()
    func disconnect(error: Error?)
    func add(task: PeerTask)
    func filterLoad(bloomFilter: BloomFilter)
    func sendMempoolMessage()
    func sendPing(nonce: UInt64)
    func equalTo(_ peer: IPeer?) -> Bool
}

public protocol PeerDelegate: class {
    func peerReady(_ peer: IPeer)
    func peerBusy(_ peer: IPeer)
    func peerDidConnect(_ peer: IPeer)
    func peerDidDisconnect(_ peer: IPeer, withError error: Error?)

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask)
    func peer(_ peer: IPeer, didReceiveMessage message: IMessage)
}

public protocol IPeerTaskRequester: class {
    var protocolVersion: Int32 { get }
    func send(message: IMessage)
}

public protocol IPeerTaskDelegate: class {
    func handle(completedTask task: PeerTask)
    func handle(failedTask task: PeerTask, error: Error)
}

protocol IPeerConnection: class {
    var delegate: PeerConnectionDelegate? { get set }
    var host: String { get }
    var port: UInt32 { get }
    var logName: String { get }
    func connect()
    func disconnect(error: Error?)
    func send(message: IMessage)
}

protocol IConnectionTimeoutManager: class {
    func reset()
    func timePeriodPassed(peer: IPeer)
}

protocol ISyncStateListener: class {
    func syncFinished()
    func syncStarted()
    func syncStopped()
    func initialBestBlockHeightUpdated(height: Int32)
    func currentBestBlockHeightUpdated(height: Int32, maxBlockHeight: Int32)
}

protocol IPeerAddressManagerDelegate: class {
    func newIpsAdded()
}

protocol IPeerDiscovery {
    var peerAddressManager: IPeerAddressManager? { get set }
    func lookup(dnsSeed: String)
}

protocol IFactory {
    func block(withHeader header: BlockHeader, previousBlock: Block) -> Block
    func block(withHeader header: BlockHeader, height: Int) -> Block
    func blockHash(withHeaderHash headerHash: Data, height: Int, order: Int) -> BlockHash
    func peer(withHost host: String, logger: Logger?) -> IPeer
    func transaction(version: Int, lockTime: Int) -> Transaction
    func inputToSign(withPreviousOutput: UnspentOutput, script: Data, sequence: Int) -> InputToSign
    func output(withIndex index: Int, address: Address, value: Int, publicKey: PublicKey?) throws -> Output
    func bloomFilter(withElements: [Data]) -> BloomFilter
}

public protocol ISyncTransactionApi {
    func getTransactions(addresses: [String]) -> Observable<[SyncTransactionItem]>
}

protocol ISyncManager {
    func start()
    func stop()
}

protocol IInitialSyncer {
    var delegate: IInitialSyncerDelegate? { get set }
    func sync()
    func stop()
}

public protocol IHasher {
    func hash(data: Data) -> Data
}

protocol IBlockHashFetcher {
    func getBlockHashes(publicKeys: [PublicKey]) -> Observable<(responses: [BlockHash], lastUsedIndex: Int)>
}

protocol IBlockHashFetcherHelper {
    func lastUsedIndex(addresses: [[String]], outputs: [SyncTransactionOutputItem]) -> Int
}

protocol IInitialSyncerDelegate: class {
    func syncingFinished()
}

protocol IPaymentAddressParser {
    func parse(paymentAddress: String) -> BitcoinPaymentData
}

public protocol IAddressConverter {
    func convert(address: String) throws -> Address
    func convert(keyHash: Data, type: ScriptType) throws -> Address
    func convert(publicKey: PublicKey, type: ScriptType) throws -> Address
}

public protocol IScriptConverter {
    func decode(data: Data) throws -> Script
}

protocol IScriptExtractor: class {
    var type: ScriptType { get }
    func extract(from data: Data, converter: IScriptConverter) throws -> Data?
}

protocol IOutputsCache: class {
    func add(fromOutputs outputs: [Output])
    func hasOutputs(forInputs inputs: [Input]) -> Bool
    func clear()
}

public protocol ITransactionProcessor: class {
    var listener: IBlockchainDataListener? { get set }

    func processReceived(transactions: [FullTransaction], inBlock block: Block?, skipCheckBloomFilter: Bool) throws
    func processCreated(transaction: FullTransaction) throws
    func processInvalid(transactionHash: Data)
}

protocol ITransactionExtractor {
    func extract(transaction: FullTransaction)
}

protocol ITransactionOutputAddressExtractor {
    func extractOutputAddresses(transaction: FullTransaction)
}

protocol ITransactionLinker {
    func handle(transaction: FullTransaction)
}

protocol ITransactionPublicKeySetter {
    func set(output: Output) -> Bool
}

public protocol ITransactionSyncer: class {
    func newTransactions() -> [FullTransaction]
    func handleRelayed(transactions: [FullTransaction])
    func handleInvalid(fullTransaction: FullTransaction)
    func shouldRequestTransaction(hash: Data) -> Bool
}

public protocol ITransactionCreator {
    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool, pluginData: [UInt8: IPluginData]) throws -> FullTransaction
    func create(from: UnspentOutput, to address: String, feeRate: Int) throws -> FullTransaction
}

protocol ITransactionBuilder {
    func buildTransaction(toAddress: String, value: Int, feeRate: Int, senderPay: Bool, pluginData: [UInt8: IPluginData]) throws -> FullTransaction
    func buildTransaction(from: UnspentOutput, toAddress: String, feeRate: Int) throws -> FullTransaction
}

protocol ITransactionFeeCalculator {
    func fee(for value: Int, feeRate: Int, senderPay: Bool, toAddress: String?, pluginData: [UInt8: IPluginData]) throws -> Int
}

protocol IBlockchain {
    var listener: IBlockchainDataListener? { get set }

    func connect(merkleBlock: MerkleBlock) throws -> Block
    func forceAdd(merkleBlock: MerkleBlock, height: Int) throws -> Block
    func handleFork() throws
    func deleteBlocks(blocks: [Block]) throws
}

public protocol IBlockchainDataListener: class {
    func onUpdate(updated: [Transaction], inserted: [Transaction], inBlock: Block?)
    func onDelete(transactionHashes: [String])
    func onInsert(block: Block)
}


protocol IInputSigner {
    func sigScriptData(transaction: Transaction, inputsToSign: [InputToSign], outputs: [Output], index: Int) throws -> [Data]
}

public protocol ITransactionSizeCalculator {
    func transactionSize(inputs: [ScriptType], outputScriptTypes: [ScriptType]) -> Int
    func transactionSize(inputs: [ScriptType], outputScriptTypes: [ScriptType], pluginDataOutputSize: Int) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func witnessSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
}

protocol IDustCalculator {
    func dust(type: ScriptType) -> Int
}

public protocol IUnspentOutputSelector {
    func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool, dust: Int, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo
}

public protocol IUnspentOutputProvider {
    var spendableUtxo: [UnspentOutput] { get }
}

public protocol IBalanceProvider {
    var balanceInfo: BalanceInfo { get }
}

public protocol IBlockSyncer: class {
    var localDownloadedBestBlockHeight: Int32 { get }
    var localKnownBestBlockHeight: Int32 { get }
    func prepareForDownload()
    func downloadStarted()
    func downloadIterationCompleted()
    func downloadCompleted()
    func downloadFailed()
    func getBlockHashes() -> [BlockHash]
    func getBlockLocatorHashes(peerLastBlockHeight: Int32) -> [Data]
    func add(blockHashes: [Data])
    func handle(merkleBlock: MerkleBlock, maxBlockHeight: Int32) throws
    func shouldRequestBlock(withHash hash: Data) -> Bool
}

protocol IKitStateProvider: class {
    var syncState: BitcoinCore.KitState { get }
    var delegate: IKitStateProviderDelegate? { get set }
}

protocol IKitStateProviderDelegate: class {
    func handleKitStateUpdate(state: BitcoinCore.KitState)
}

public protocol ITransactionInfo: class {
    init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, fee: Int?, blockHeight: Int?, timestamp: Int, status: TransactionStatus)
}

public protocol ITransactionInfoConverter {
    var baseTransactionInfoConverter: IBaseTransactionInfoConverter! { get set }
    func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo
}

protocol IDataProvider {
    var delegate: IDataProviderDelegate? { get set }

    var lastBlockInfo: BlockInfo? { get }
    var balance: BalanceInfo { get }
    func debugInfo(network: INetwork, scriptType: ScriptType, addressConverter: IAddressConverter) -> String
    func transactions(fromHash: String?, limit: Int?) -> Single<[TransactionInfo]>
}

protocol IDataProviderDelegate: class {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: BalanceInfo)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
}

public protocol INetwork: class {
    var maxBlockSize: UInt32 { get }
    var protocolVersion: Int32 { get }
    var name: String { get }
    var pubKeyHash: UInt8 { get }
    var privateKey: UInt8 { get }
    var scriptHash: UInt8 { get }
    var bech32PrefixPattern: String { get }
    var xPubKey: UInt32 { get }
    var xPrivKey: UInt32 { get }
    var magic: UInt32 { get }
    var port: UInt32 { get }
    var dnsSeeds: [String] { get }
    var dustRelayTxFee: Int { get }
    var bip44CheckpointBlock: Block { get }
    var lastCheckpointBlock: Block { get }
    var coinType: UInt32 { get }
    var sigHash: SigHashType { get }
    var syncableFromApi: Bool { get }
}

protocol IMerkleBlockValidator: class {
    func set(merkleBranch: IMerkleBranch)
    func merkleBlock(from message: MerkleBlockMessage) throws -> MerkleBlock
}

public protocol IMerkleBranch: class {
    func calculateMerkleRoot(txCount: Int, hashes: [Data], flags: [UInt8]) throws -> (merkleRoot: Data, matchedHashes: [Data])
}

public extension INetwork {
    var protocolVersion: Int32 { 70015 }

    var maxBlockSize: UInt32 { 1_000_000 }
    var serviceFullNode: UInt64 { 1 }
    var bloomFilter: Int32 { 70000 }

}

public protocol IMessage {
    var description: String { get }
}

protocol INetworkMessageParser {
    func parse(data: Data) -> NetworkMessage?
}

public protocol IMessageParser {
    var id: String { get }
    func parse(data: Data) -> IMessage
}

protocol IBlockHeaderParser {
    func parse(byteStream: ByteStream) -> BlockHeader
}

protocol INetworkMessageSerializer {
    func serialize(message: IMessage) throws -> Data
}

public protocol IMessageSerializer {
    var id: String { get }
    func serialize(message: IMessage) -> Data?
}

public protocol IInitialBlockDownload {
    var syncPeer: IPeer? { get }
    var hasSyncedPeer: Bool { get }
    var observable: Observable<InitialBlockDownloadEvent> { get }
    var syncedPeers: [IPeer] { get }
    func isSynced(peer: IPeer) -> Bool
}

public protocol ISyncedReadyPeerManager {
    var peers: [IPeer] { get }
    var observable: Observable<Void> { get }
}

public protocol IInventoryItemsHandler: class {
    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem])
}

public protocol IPeerTaskHandler: class {
    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool
}

protocol ITransactionSender {
    func verifyCanSend() throws
    func send(pendingTransaction: FullTransaction) throws
    func transactionsRelayed(transactions: [FullTransaction])
}

protocol ITransactionSendTimerDelegate: class {
    func timePassed()
}

protocol ITransactionSendTimer {
    var delegate: ITransactionSendTimerDelegate? { get set }
    func startIfNotRunning()
    func stop()
}

protocol IMerkleBlockHandler: AnyObject {
    func handle(merkleBlock: MerkleBlock) throws
}

protocol ITransactionListener: class {
    func onReceive(transaction: FullTransaction)
}

public protocol IWatchedTransactionDelegate {
    func transactionReceived(transaction: FullTransaction, outputIndex: Int)
    func transactionReceived(transaction: FullTransaction, inputIndex: Int)
}

protocol IWatchedTransactionManager {
    func add(transactionFilter: BitcoinCore.TransactionFilter, delegatedTo: IWatchedTransactionDelegate)
}

protocol IBloomFilterProvider: AnyObject {
    var bloomFilterManager: IBloomFilterManager? { set get }
    func filterElements() -> [Data]
}

protocol IIrregularOutputFinder {
    func hasIrregularOutput(outputs: [Output]) -> Bool
}

public protocol IPlugin {
    var id: UInt8 { get }
    var maxSpendLimit: Int? { get }
    func validate(address: Address) throws
    func processOutputs(mutableTransaction: MutableTransaction, pluginData: IPluginData) throws
    func processTransactionWithNullData(transaction: FullTransaction, nullDataChunks: inout IndexingIterator<[Chunk]>) throws
    func isSpendable(unspentOutput: UnspentOutput) throws -> Bool
    func inputSequenceNumber(output: Output) throws -> Int
    func parsePluginData(from: String, transactionTimestamp: Int) throws -> IPluginOutputData
    func keysForApiRestore(publicKey: PublicKey) throws -> [String]
}

public protocol IPluginManager {
    func validate(address: Address, pluginData: [UInt8: IPluginData]) throws
    func maxSpendLimit(pluginData: [UInt8: IPluginData]) throws -> Int?
    func add(plugin: IPlugin)
    func processOutputs(mutableTransaction: MutableTransaction, pluginData: [UInt8: IPluginData]) throws
    func processInputs(mutableTransaction: MutableTransaction) throws
    func processTransactionWithNullData(transaction: FullTransaction, nullDataOutput: Output) throws
    func isSpendable(unspentOutput: UnspentOutput) -> Bool
    func parsePluginData(fromPlugin: UInt8, pluginDataString: String, transactionTimestamp: Int) -> IPluginOutputData?
}

public protocol IBlockMedianTimeHelper {
    var medianTimePast: Int? { get }
    func medianTimePast(block: Block) -> Int?
}

protocol IOutputSetter {
    func setOutputs(to mutableTransaction: MutableTransaction, toAddress: String, value: Int, pluginData: [UInt8: IPluginData]) throws
}

protocol IInputSetter {
    func setInputs(to mutableTransaction: MutableTransaction, feeRate: Int, senderPay: Bool) throws
    func setInputs(to mutableTransaction: MutableTransaction, fromUnspentOutput unspentOutput: UnspentOutput, feeRate: Int) throws
}

protocol ILockTimeSetter {
    func setLockTime(to mutableTransaction: MutableTransaction)
}

protocol ITransactionSigner {
    func sign(mutableTransaction: MutableTransaction) throws
}

public protocol IPluginData {
}

public protocol IPluginOutputData {
}
