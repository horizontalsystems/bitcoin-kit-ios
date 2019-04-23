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
    func markSuccess(ip: String)
    func markFailed(ip: String)
    func add(ips: [String])
}

protocol IStateManager {
    var restored: Bool { get set }
}

protocol IBlockDiscovery {
    func discoverBlockHashes(account: Int, external: Bool) -> Observable<([PublicKey], [BlockHash])>
}

protocol IFeeRateApi {
    func getFeeRate() -> Observable<FeeRate>
}

public protocol IStorage {
    var feeRate: FeeRate? { get }
    func set(feeRate: FeeRate)

    var initialRestored: Bool? { get }
    func set(initialRestored: Bool)

    func existingPeerAddresses(fromIps ips: [String]) -> [PeerAddress]
    func leastScorePeerAddress(excludingIps: [String]) -> PeerAddress?
    func save(peerAddresses: [PeerAddress])
    func increasePeerAddressScore(ip: String)
    func deletePeerAddress(byIp ip: String)



    var blockchainBlockHashes: [BlockHash] { get }
    var lastBlockchainBlockHash: BlockHash? { get }
    func blockHashHeaderHashes(except: Data) -> [String]
    var blockHashHeaderHashes: [Data] { get }
    var lastBlockHash: BlockHash? { get }
    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash]
    func add(blockHashes: [BlockHash])
    func deleteBlockHash(byHash: Data)
    func deleteBlockchainBlockHashes()

    var blocksCount: Int { get }
    var lastBlock: Block? { get }
    func blocksCount(headerHashes: [Data]) -> Int
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


    func transaction(byHash: Data) -> Transaction?
    func transactions(ofBlock: Block) -> [Transaction]
    func newTransactions() -> [Transaction]
    func newTransaction(byHash: Data) -> Transaction?
    func relayedTransactionExists(byHash: Data) -> Bool
    func add(transaction: FullTransaction) throws
    func update(transaction: Transaction) throws
    func fullInfo(forTransactions: [TransactionWithBlock]) -> [FullTransactionForInfo]
    func fullTransactionsInfo(fromTimestamp: Int?, fromOrder: Int?, limit: Int?) -> [FullTransactionForInfo]

    func outputsWithPublicKeys() -> [OutputWithPublicKey]
    func unspentOutputs() -> [UnspentOutput]
    func inputs(ofTransaction: Transaction) -> [Input]
    func outputs(ofTransaction: Transaction) -> [Output]
    func previousOutput(ofInput: Input) -> Output?

    func sentTransaction(byHash: Data) -> SentTransaction?
    func update(sentTransaction: SentTransaction)
    func add(sentTransaction: SentTransaction)

    func publicKeys() -> [PublicKey]
    func publicKey(byPath: String) -> PublicKey?
    func publicKey(byScriptHashForP2WPKH: Data) -> PublicKey?
    func publicKey(byRawOrKeyHash: Data) -> PublicKey?
    func add(publicKeys: [PublicKey])
    func publicKeysWithUsedState() -> [PublicKeyWithUsedState]

    func clear() throws
}

protocol IFeeRateSyncer {
    func sync()
}

public protocol IAddressSelector {
    func getAddressVariants(addressConverter: IAddressConverter, publicKey: PublicKey) -> [String]
}

protocol IAddressManager {
    func changePublicKey() throws -> PublicKey
    func receiveAddress() throws -> String
    func fillGap() throws
    func addKeys(keys: [PublicKey]) throws
    func gapShifts() -> Bool
}

protocol IBloomFilterManagerDelegate: class {
    func bloomFilterUpdated(bloomFilter: BloomFilter)
}

protocol IBloomFilterManager {
    var delegate: IBloomFilterManagerDelegate? { get set }
    var bloomFilter: BloomFilter? { get }
    func regenerateBloomFilter()
}


public protocol IPeerGroup: class {
    var blockSyncer: IBlockSyncer? { get set }
    var transactionSyncer: ITransactionSyncer? { get set }
    var someReadyPeers: [IPeer] { get }

    func start()
    func stop()
    func checkPeersSynced() throws

    func addTask(peerTask: PeerTask)
    func add(peerGroupListener: IPeerGroupListener)
}

protocol IPeerManager: class {
    func add(peer: IPeer)
    func peerDisconnected(peer: IPeer)
    func disconnectAll()
    func totalPeersCount() -> Int
    func someReadyPeers() -> [IPeer]
    func connected() -> [IPeer]
    func nonSyncedPeer() -> IPeer?
    func halfIsSynced() -> Bool
}

public protocol IPeer: class {
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

public protocol PeerDelegate: class {
    func peerReady(_ peer: IPeer)
    func peerDidConnect(_ peer: IPeer)
    func peerDidDisconnect(_ peer: IPeer, withError error: Error?)

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask)
    func peer(_ peer: IPeer, didReceiveAddresses addresses: [NetworkAddress])
    func peer(_ peer: IPeer, didReceiveInventoryItems items: [InventoryItem])
}

public protocol IPeerTaskRequester: class {
    func getBlocks(hashes: [Data])
    func getData(items: [InventoryItem])
    func sendTransactionInventory(hash: Data)
    func send(transaction: FullTransaction)
    func send(message: IMessage)
    func ping(nonce: UInt64)
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
    func syncStarted()
    func syncStopped()
    func syncFinished()
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
    func output(withValue value: Int, index: Int, lockingScript script: Data, type: ScriptType, address: String?, keyHash: Data?, publicKey: PublicKey?) -> Output
    func bloomFilter(withElements: [Data]) -> BloomFilter
}

protocol IBCoinApi {
    func getTransactions(addresses: [String]) -> Observable<[BCoinApi.TransactionItem]>
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
    func lastUsedIndex(addresses: [[String]], outputs: [BCoinApi.TransactionOutputItem]) -> Int
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
}

public protocol IScriptConverter {
    func decode(data: Data) throws -> Script
}

protocol IScriptExtractor: class {
    var type: ScriptType { get }
    func extract(from data: Data, converter: IScriptConverter) throws -> Data?
}

protocol ITransactionProcessor: class {
    var listener: IBlockchainDataListener? { get set }

    func processReceived(transactions: [FullTransaction], inBlock block: Block?, skipCheckBloomFilter: Bool) throws
    func processCreated(transaction: FullTransaction) throws
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
    func pendingTransactions() -> [FullTransaction]
    func handle(transactions: [FullTransaction])
    func handle(sentTransaction transaction: FullTransaction)
    func shouldRequestTransaction(hash: Data) -> Bool
}

protocol ITransactionCreator {
    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool) throws
}

protocol ITransactionBuilder {
    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String?) throws -> Int
    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, toAddress: String) throws -> FullTransaction
}

protocol IBlockchain {
    var listener: IBlockchainDataListener? { get set }

    func connect(merkleBlock: MerkleBlock) throws -> Block
    func forceAdd(merkleBlock: MerkleBlock, height: Int) throws -> Block
    func handleFork() throws
    func deleteBlocks(blocks: [Block]) throws
}

protocol IBlockchainDataListener: class {
    func onUpdate(updated: [Transaction], inserted: [Transaction], inBlock: Block?)
    func onDelete(transactionHashes: [String])
    func onInsert(block: Block)
}


protocol IInputSigner {
    func sigScriptData(transaction: Transaction, inputsToSign: [InputToSign], outputs: [Output], index: Int) throws -> [Data]
}

public protocol IScriptBuilder {
    func lockingScript(for address: Address) throws -> Data
}

protocol ITransactionSizeCalculator {
    func transactionSize(inputs: [ScriptType], outputScriptTypes: [ScriptType]) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
}

protocol IUnspentOutputSelector {
    func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool, unspentOutputs: [UnspentOutput]) throws -> SelectedUnspentOutputInfo
}

protocol IUnspentOutputProvider {
    var allUnspentOutputs: [UnspentOutput] { get }
    var balance: Int { get }
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

protocol IDataProvider {
    var delegate: IDataProviderDelegate? { get set }

    var lastBlockInfo: BlockInfo? { get }
    var balance: Int { get }
    var feeRate: FeeRate { get }
    func transactions(fromHash: String?, limit: Int?) -> Single<[TransactionInfo]>
    var debugInfo: String { get }
}

protocol IDataProviderDelegate: class {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: Int)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
}

public protocol INetwork: class {
    var maxBlockSize: UInt32 { get }
    var protocolVersion: Int32 { get }
    var name: String { get }
    var pubKeyHash: UInt8 { get }
    var privateKey: UInt8 { get }
    var scriptHash: UInt8 { get }
    var pubKeyPrefixPattern: String { get }
    var scriptPrefixPattern: String { get }
    var bech32PrefixPattern: String { get }
    var xPubKey: UInt32 { get }
    var xPrivKey: UInt32 { get }
    var magic: UInt32 { get }
    var port: UInt32 { get }
    var dnsSeeds: [String] { get }
    var genesisBlock: Block { get }
    var checkpointBlock: Block { get }
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
    var protocolVersion: Int32 { return 70015 }

    var maxBlockSize: UInt32 { return 1_000_000 }
    var serviceFullNode: UInt64 { return 1 }
    var bloomFilter: Int32 { return 70000 }

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
    func serialize(message: IMessage) throws -> Data
}

public protocol IInventoryItemsHandler {
    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem])
}

public protocol IPeerTaskHandler {
    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool
}

protocol IAllPeersSyncedDelegate {
    func onAllPeersSynced()
}

protocol ITransactionSender {
    func sendPendingTransactions()
    func canSendTransaction() throws
}

public protocol IPeerGroupListener {
    func onStart()
    func onStop()
    func onPeerCreate(peer: IPeer)
    func onPeerConnect(peer: IPeer)
    func onPeerDisconnect(peer: IPeer, error: Error?)
    func onPeerReady(peer: IPeer)
}

extension IPeerGroupListener {
    func onStart() {}
    func onStop() {}
    func onPeerCreate(peer: IPeer) {}
    func onPeerConnect(peer: IPeer) {}
    func onPeerDisconnect(peer: IPeer, error: Error?) {}
    func onPeerReady(peer: IPeer) {}
}

protocol IMerkleBlockHandler {
    func handle(merkleBlock: MerkleBlock) throws
}
