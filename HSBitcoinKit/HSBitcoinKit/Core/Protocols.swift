import BigInt
import RxSwift
import RealmSwift
import Alamofire
import HSCryptoKit
import GRDB

enum BlockValidatorType { case header, bits, legacy, testNet, EDA, DAA, DGW }

protocol IDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

protocol IBlockHelper {
    func previous(for block: Block, index: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
    func medianTimePast(block: Block) throws -> Int
}

protocol IBlockValidator: class {
    func validate(candidate: Block, block: Block, network: INetwork) throws
}

protocol IBlockValidatorFactory {
    func validator(for validatorType: BlockValidatorType) -> IBlockValidator
}

protocol IRealmFactory {
    var realm: Realm { get }
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

protocol IStorage {
    var realm: Realm { get }

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
    func blockHashHeaderHashHexes(except: String) -> [String]
    func deleteBlockchainBlockHashes()

    var blockHashHeaderHashes: [Data] { get }
    var lastBlockHash: BlockHash? { get }
    func blockHashes(filters: [(fieldName: BlockHash.Columns, value: Any, equal: Bool)], orders: [(fieldName: BlockHash.Columns, ascending: Bool)]) -> [BlockHash]
    func blockHashesSortedBySequenceAndHeight(limit: Int) -> [BlockHash]
    func add(blockHashes: [BlockHash])
    func deleteBlockHash(byHashHex: String)

    var blocksCount: Int { get }
    var lastBlock: Block? { get }
    func blocksCount(reversedHeaderHashHexes: [String]) -> Int
    func save(block: Block)
    func blocks(heightGreaterThan: Int, sortedBy: String, limit: Int) -> [Block]
    func blocks(byHexes: [String], realm: Realm) -> Results<Block>
    func block(byHeight: Int32) -> Block?
    func block(byHeaderHash: Data) -> Block?


    func newTransactions() -> [Transaction]
    func newTransaction(byReversedHashHex: String) -> Transaction?
    func relayedTransactionExists(byReversedHashHex: String) -> Bool


    func sentTransaction(byReversedHashHex: String) -> SentTransaction?
    func update(sentTransaction: SentTransaction)
    func add(sentTransaction: SentTransaction)


    func clear() throws
    func inTransaction(_ block: ((_ realm: Realm) throws -> Void)) throws
}

protocol IFeeRateSyncer {
    func sync()
}

protocol IAddressSelector {
    func getAddressVariants(publicKey: PublicKey) -> [String]
}

protocol IAddressManager {
    func changePublicKey() throws -> PublicKey
    func receiveAddress() throws -> String
    func fillGap() throws
    func addKeys(keys: [PublicKey]) throws
    func gapShifts() -> Bool
}

protocol IBloomFilterManager {
    var delegate: BloomFilterManagerDelegate? { get set }
    var bloomFilter: BloomFilter? { get }
    func regenerateBloomFilter()
}

protocol BloomFilterManagerDelegate: class {
    func bloomFilterUpdated(bloomFilter: BloomFilter)
}

protocol IPeerGroup: class {
    var blockSyncer: IBlockSyncer? { get set }
    var transactionSyncer: ITransactionSyncer? { get set }
    func start()
    func stop()
    func sendPendingTransactions() throws
    func checkPeersSynced() throws
}

protocol IPeerManager: class {
    var syncPeer: IPeer? { get set }
    func add(peer: IPeer)
    func peerDisconnected(peer: IPeer)
    func disconnectAll()
    func totalPeersCount() -> Int
    func someReadyPeers() -> [IPeer]
    func connected() -> [IPeer]
    func nonSyncedPeer() -> IPeer?
    func syncPeerIs(peer: IPeer) -> Bool
}

protocol IPeer: class {
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
    func isRequestingInventory(hash: Data) -> Bool
    func filterLoad(bloomFilter: BloomFilter)
    func sendMempoolMessage()
    func sendPing(nonce: UInt64)
    func equalTo(_ peer: IPeer?) -> Bool
}

protocol PeerDelegate: class {
    func handle(_ peer: IPeer, merkleBlock: MerkleBlock)
    func peerReady(_ peer: IPeer)
    func peerDidConnect(_ peer: IPeer)
    func peerDidDisconnect(_ peer: IPeer, withError error: Error?)

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask)
    func peer(_ peer: IPeer, didReceiveAddresses addresses: [NetworkAddress])
    func peer(_ peer: IPeer, didReceiveInventoryItems items: [InventoryItem])
}

protocol IPeerTaskRequester: class {
    func getBlocks(hashes: [Data])
    func getData(items: [InventoryItem])
    func sendTransactionInventory(hash: Data)
    func send(transaction: Transaction)
    func ping(nonce: UInt64)
}

protocol IPeerTaskDelegate: class {
    func handle(completedTask task: PeerTask)
    func handle(failedTask task: PeerTask, error: Error)
    func handle(merkleBlock: MerkleBlock)
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
    func peer(withHost host: String, network: INetwork, networkMessageParser: NetworkMessageParser, logger: Logger?) -> IPeer
    func transaction(version: Int, inputs: [TransactionInput], outputs: [TransactionOutput], lockTime: Int) -> Transaction
    func transactionInput(withPreviousOutputTxReversedHex previousOutputTxReversedHex: String, previousOutputIndex: Int, script: Data, sequence: Int) -> TransactionInput
    func transactionOutput(withValue value: Int, index: Int, lockingScript script: Data, type: ScriptType, address: String?, keyHash: Data?, publicKey: PublicKey?) -> TransactionOutput
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

protocol IBech32AddressConverter {
    func convert(prefix: String, address: String) throws -> Address
    func convert(prefix: String, keyData: Data, scriptType: ScriptType) throws -> Address
}

protocol IAddressConverter {
    func convert(address: String) throws -> Address
    func convert(keyHash: Data, type: ScriptType) throws -> Address
    func convertToLegacy(keyHash: Data, version: UInt8, addressType: AddressType) -> LegacyAddress
}

protocol IScriptConverter {
    func decode(data: Data) throws -> Script
}

protocol IScriptExtractor: class {
    var type: ScriptType { get }
    func extract(from data: Data, converter: IScriptConverter) throws -> Data?
}

protocol ITransactionProcessor: class {
    var listener: IBlockchainDataListener? { get set }

    func process(transactions: [Transaction], inBlock block: Block?, skipCheckBloomFilter: Bool, realm: Realm) throws
    func processOutgoing(transaction: Transaction, realm: Realm) throws
}

protocol ITransactionExtractor {
    func extract(transaction: Transaction)
}

protocol ITransactionOutputAddressExtractor {
    func extractOutputAddresses(transaction: Transaction)
}

protocol ITransactionLinker {
    func handle(transaction: Transaction, realm: Realm)
}

protocol ITransactionPublicKeySetter {
    func set(output: TransactionOutput) -> Bool
}

protocol ITransactionSyncer: class {
    func pendingTransactions() -> [Transaction]
    func handle(transactions: [Transaction])
    func handle(sentTransaction transaction: Transaction)
    func shouldRequestTransaction(hash: Data) -> Bool
}

protocol ITransactionCreator {
    func create(to address: String, value: Int, feeRate: Int, senderPay: Bool) throws
}

protocol ITransactionBuilder {
    func fee(for value: Int, feeRate: Int, senderPay: Bool, address: String?) throws -> Int
    func buildTransaction(value: Int, feeRate: Int, senderPay: Bool, toAddress: String) throws -> Transaction
}

protocol IBlockchain {
    var listener: IBlockchainDataListener? { get set }

    func connect(merkleBlock: MerkleBlock, realm: Realm) throws -> Block
    func forceAdd(merkleBlock: MerkleBlock, height: Int, realm: Realm) -> Block
    func handleFork(realm: Realm)
    func deleteBlocks(blocks: Results<Block>, realm: Realm)
}

protocol IBlockchainDataListener: class {
    func onUpdate(updated: [Transaction], inserted: [Transaction])
    func onDelete(transactionHashes: [String])
    func onInsert(block: Block)
}


protocol IInputSigner {
    func sigScriptData(transaction: Transaction, index: Int) throws -> [Data]
}

protocol IScriptBuilder {
    func lockingScript(for address: Address) throws -> Data
    func unlockingScript(params: [Data]) -> Data
}

protocol ITransactionSizeCalculator {
    func transactionSize(inputs: [ScriptType], outputScriptTypes: [ScriptType]) -> Int
    func outputSize(type: ScriptType) -> Int
    func inputSize(type: ScriptType) -> Int
    func toBytes(fee: Int) -> Int
}

protocol IUnspentOutputSelector {
    func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool, outputs: [TransactionOutput]) throws -> SelectedUnspentOutputInfo
}

protocol IUnspentOutputProvider {
    var allUnspentOutputs: [TransactionOutput] { get }
    var balance: Int { get }
}

protocol IBlockSyncer: class {
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
    var syncState: BitcoinKit.KitState { get }
    var delegate: IKitStateProviderDelegate? { get set }
}

protocol IKitStateProviderDelegate: class {
    func handleKitStateUpdate(state: BitcoinKit.KitState)
}

protocol IDataProvider {
    var delegate: IDataProviderDelegate? { get set }

    var lastBlockInfo: BlockInfo? { get }
    var balance: Int { get }
    var receiveAddress: String { get }
    func transactions(fromHash: String?, limit: Int?) -> Single<[TransactionInfo]>
    func send(to address: String, value: Int) throws
    func parse(paymentAddress: String) -> BitcoinPaymentData
    func validate(address: String) throws
    func fee(for value: Int, toAddress: String?, senderPay: Bool) throws -> Int

    var debugInfo: String { get }
}

protocol IDataProviderDelegate: class {
    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(balance: Int)
    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo)
}

protocol INetwork: class {
    var merkleBlockValidator: IMerkleBlockValidator { get }

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

    // difficulty adjustment params
    var maxTargetBits: Int { get }                                      // Maximum difficulty.

    var targetTimeSpan: Int { get }                                     // seconds per difficulty cycle, on average.
    var targetSpacing: Int { get }                                      // minutes per block.
    var heightInterval: Int { get }                                     // Blocks in cycle

    func validate(block: Block, previousBlock: Block) throws
    func generateBlockHeaderHash(from data: Data) -> Data
}

protocol IMerkleBlockValidator: class {
    func merkleBlock(from message: MerkleBlockMessage) throws -> MerkleBlock
}

extension INetwork {
    var protocolVersion: Int32 { return 70015 }

    var serviceFullNode: UInt64 { return 1 }
    var bloomFilter: Int32 { return 70000 }
    var maxTargetBits: Int { return 0x1d00ffff }

    var targetTimeSpan: Int { return 14 * 24 * 60 * 60 }                // Seconds in Bitcoin cycle
    var targetSpacing: Int { return 10 * 60 }                           // 10 min. for mining 1 Block (Bitcoin)

    var heightInterval: Int { return targetTimeSpan / targetSpacing }   // 2016 Blocks in Bitcoin cycle

    func isDifficultyTransitionPoint(height: Int) -> Bool {
        return height % heightInterval == 0
    }

    func generateBlockHeaderHash(from data: Data) -> Data {
        return CryptoKit.sha256sha256(data)
    }

}
