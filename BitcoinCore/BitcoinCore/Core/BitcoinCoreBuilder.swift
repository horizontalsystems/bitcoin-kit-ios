import Foundation
import HSHDWalletKit

public class BitcoinCoreBuilder {
    public enum BuildError: Error { case noSeedData, noWalletId, noNetwork, noPaymentAddressParser, noAddressSelector, noStorage }

    // required parameters
    private var seed: Data?
    private var words: [String]?
    private var network: INetwork?
    private var paymentAddressParser: IPaymentAddressParser?
    private var addressSelector: IAddressSelector?
    private var walletId: String?
    private var initialSyncApiUrl: String?
    private var logger: Logger

    private var blockHeaderHasher: IHasher?
    private var unspentOutputSelector: IUnspentOutputSelector?

    // parameters with default values
    private var confirmationsThreshold = 6
    private var newWallet = false
    private var peerCount = 10

    private var storage: IStorage?

    public func set(seed: Data) -> BitcoinCoreBuilder {
        self.seed = seed
        return self
    }

    public func set(words: [String]) -> BitcoinCoreBuilder {
        self.words = words
        return self
    }

    public func set(network: INetwork) -> BitcoinCoreBuilder {
        self.network = network
        return self
    }

    public func set(paymentAddressParser: PaymentAddressParser) -> BitcoinCoreBuilder {
        self.paymentAddressParser = paymentAddressParser
        return self
    }

    public func set(addressSelector: IAddressSelector) -> BitcoinCoreBuilder {
        self.addressSelector = addressSelector
        return self
    }

    public func set(walletId: String) -> BitcoinCoreBuilder {
        self.walletId = walletId
        return self
    }

    public func set(confirmationsThreshold: Int) -> BitcoinCoreBuilder {
        self.confirmationsThreshold = confirmationsThreshold
        return self
    }

    public func set(newWallet: Bool) -> BitcoinCoreBuilder {
        self.newWallet = newWallet
        return self
    }

    public func set(peerSize: Int) -> BitcoinCoreBuilder {
        self.peerCount = peerSize
        return self
    }

    public func set(storage: IStorage) -> BitcoinCoreBuilder {
        self.storage = storage
        return self
    }

    public func set(blockHeaderHasher: IHasher) -> BitcoinCoreBuilder {
        self.blockHeaderHasher = blockHeaderHasher
        return self
    }

    public func set(unspentOutputSelector: IUnspentOutputSelector) -> BitcoinCoreBuilder {
        self.unspentOutputSelector = unspentOutputSelector
        return self
    }

    public func set(initialSyncApiUrl: String?) -> BitcoinCoreBuilder {
        self.initialSyncApiUrl = initialSyncApiUrl
        return self
    }

    public init(minLogLevel: Logger.Level = .verbose) {
        self.logger = Logger(network: network, minLogLevel: minLogLevel)
    }

    public func build() throws -> BitcoinCore {
        let seed: Data
        if let selfSeed = self.seed {
           seed = selfSeed
        } else if let words = self.words {
            seed = Mnemonic.seed(mnemonic: words)
        } else {
            throw BuildError.noSeedData
        }
//        guard let walletId = self.walletId else {
//            throw BuildError.noWalletId
//        }
        guard let network = self.network else {
            throw BuildError.noNetwork
        }
        guard let paymentAddressParser = self.paymentAddressParser else {
            throw BuildError.noPaymentAddressParser
        }
        guard let addressSelector = self.addressSelector else {
            throw BuildError.noAddressSelector
        }
        guard let storage = self.storage else {
            throw BuildError.noStorage
        }

        let addressConverter = AddressConverterChain()

//        let dbName = "bitcoinkit-${network.javaClass}-$walletId"
//        let database = KitDatabase.getInstance(context, dbName)
//        let realmFactory = RealmFactory(dbName)
//        let storage = Storage(database, realmFactory)
//
        let unspentOutputProvider = UnspentOutputProvider(storage: storage, confirmationsThreshold: confirmationsThreshold)
        let dataProvider = DataProvider(storage: storage, unspentOutputProvider: unspentOutputProvider)

        let reachabilityManager = ReachabilityManager()

        let hdWallet = HDWallet(seed: seed, coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey, gapLimit: 20)

        let networkMessageParser = NetworkMessageParser(magic: network.magic)
        let networkMessageSerializer = NetworkMessageSerializer(magic: network.magic)

        let doubleShaHasher = DoubleShaHasher()
        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)
        let merkleBlockValidator = MerkleBlockValidator(maxBlockSize: network.maxBlockSize, merkleBranch: merkleBranch)

        let factory = Factory(network: network, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer, merkleBlockValidator: merkleBlockValidator)

        let addressManager = AddressManager.instance(storage: storage, hdWallet: hdWallet, addressConverter: addressConverter)

        let myOutputsCache = OutputsCache.instance(storage: storage)
        let scriptConverter = ScriptConverter()
        let transactionInputExtractor = TransactionInputExtractor(storage: storage, scriptConverter: scriptConverter, addressConverter: addressConverter, logger: logger)
        let transactionKeySetter = TransactionPublicKeySetter(storage: storage)
        let transactionOutputExtractor = TransactionOutputExtractor(transactionKeySetter: transactionKeySetter, logger: logger)
        let transactionAddressExtractor = TransactionOutputAddressExtractor(storage: storage, addressConverter: addressConverter)
        let transactionProcessor = TransactionProcessor(storage: storage,
                outputExtractor: transactionOutputExtractor, inputExtractor: transactionInputExtractor,
                outputsCache: myOutputsCache, outputAddressExtractor: transactionAddressExtractor,
                addressManager: addressManager, listener: dataProvider)

        let kitStateProvider = KitStateProvider()

        let peerDiscovery = PeerDiscovery()
        let peerAddressManager = PeerAddressManager(storage: storage, dnsSeeds: network.dnsSeeds, peerDiscovery: peerDiscovery, logger: logger)
        peerDiscovery.peerAddressManager = peerAddressManager
        let bloomFilterManager = BloomFilterManager(storage: storage, factory: factory)

        let peerManager = PeerManager()

        let peerGroup = PeerGroup(factory: factory, reachabilityManager: reachabilityManager,
                peerAddressManager: peerAddressManager, peerCount: peerCount, peerManager: peerManager, logger: logger)

        let unspentOutputSelector: IUnspentOutputSelector
        if let selector = self.unspentOutputSelector {
            unspentOutputSelector = selector
        } else {
            let transactionSizeCalculator = TransactionSizeCalculator()
            unspentOutputSelector = UnspentOutputSelector(calculator: transactionSizeCalculator)
        }

        let transactionSyncer = TransactionSyncer(storage: storage, processor: transactionProcessor, addressManager: addressManager, bloomFilterManager: bloomFilterManager)
        let mempoolTransactions = MempoolTransactions(transactionSyncer: transactionSyncer)

        let transactionSender = TransactionSender(transactionSyncer: transactionSyncer, peerGroup: peerGroup, logger: logger)
        let inputSigner = InputSigner(hdWallet: hdWallet, network: network)
        let scriptBuilder = ScriptBuilderChain()
        let transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, addressManager: addressManager, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        let transactionCreator = TransactionCreator(transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, transactionSender: transactionSender)

        let initialSyncApiUrl = self.initialSyncApiUrl ?? "http://btc-testnet.horizontalsystems.xyz/apg"//todo dash can't initial sync blocks. Must avoid creation of blockDiscovery
        let bcoinApi = BCoinApi(url: initialSyncApiUrl)

        let blockHashFetcher = BlockHashFetcher(addressSelector: addressSelector, apiManager: bcoinApi, addressConverter: addressConverter, helper: BlockHashFetcherHelper())
        let blockDiscovery = BlockDiscoveryBatch(network: network, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        let stateManager = StateManager(storage: storage, network: network, newWallet: newWallet)

        let initialSyncer = InitialSyncer(storage: storage, listener: kitStateProvider, stateManager: stateManager, blockDiscovery: blockDiscovery, addressManager: addressManager, logger: logger)

        let syncManager = SyncManager(reachabilityManager: reachabilityManager, initialSyncer: initialSyncer, peerGroup: peerGroup)

        let bloomFilterLoader = BloomFilterLoader(bloomFilterManager: bloomFilterManager)

        let blockValidatorChain = BlockValidatorChain(proofOfWorkValidator: ProofOfWorkValidator(difficultyEncoder: DifficultyEncoder()))
        let blockchain = Blockchain(storage: storage, blockValidator: blockValidatorChain, factory: factory, listener: dataProvider)
        let blockSyncer = BlockSyncer.instance(storage: storage, network: network, factory: factory, listener: kitStateProvider, transactionProcessor: transactionProcessor, blockchain: blockchain, addressManager: addressManager, bloomFilterManager: bloomFilterManager, logger: logger)
        let initialBlockDownload = InitialBlockDownload(blockSyncer: blockSyncer, peerManager: peerManager, syncStateListener: kitStateProvider, logger: logger)


        let bitcoinCore = BitcoinCore(storage: storage,
                cache: myOutputsCache,
                dataProvider: dataProvider,
                peerGroup: peerGroup,
                initialBlockDownload: initialBlockDownload,
                transactionSyncer: transactionSyncer,
                blockValidatorChain: blockValidatorChain,
                addressManager: addressManager,
                addressConverter: addressConverter,
                kitStateProvider: kitStateProvider,
                scriptBuilder: scriptBuilder,
                transactionBuilder: transactionBuilder,
                transactionCreator: transactionCreator,
                paymentAddressParser: paymentAddressParser,
                networkMessageParser: networkMessageParser,
                networkMessageSerializer: networkMessageSerializer,
                syncManager: syncManager)

        initialSyncer.delegate = syncManager
        bloomFilterManager.delegate = bloomFilterLoader
        dataProvider.delegate = bitcoinCore
        kitStateProvider.delegate = bitcoinCore

        bitcoinCore.peerGroup = peerGroup
        bitcoinCore.transactionSyncer = transactionSyncer

        peerGroup.peerTaskHandler = bitcoinCore.peerTaskHandlerChain
        peerGroup.inventoryItemsHandler = bitcoinCore.inventoryItemsHandlerChain

        bitcoinCore.prepend(scriptBuilder: ScriptBuilder())
        bitcoinCore.prepend(addressConverter: Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash))

        // this part can be moved to another place

        let blockHeaderParser = BlockHeaderParser(hasher: blockHeaderHasher ?? doubleShaHasher)
        bitcoinCore.add(messageParser: AddressMessageParser())
                .add(messageParser: GetDataMessageParser())
                .add(messageParser: InventoryMessageParser())
                .add(messageParser: PingMessageParser())
                .add(messageParser: PongMessageParser())
                .add(messageParser: VerackMessageParser())
                .add(messageParser: VersionMessageParser())
                .add(messageParser: MemPoolMessageParser())
                .add(messageParser: MerkleBlockMessageParser(blockHeaderParser: blockHeaderParser))
                .add(messageParser: TransactionMessageParser())

        bitcoinCore.add(messageSerializer: GetDataMessageSerializer())
                .add(messageSerializer: GetBlocksMessageSerializer())
                .add(messageSerializer: InventoryMessageSerializer())
                .add(messageSerializer: PingMessageSerializer())
                .add(messageSerializer: PongMessageSerializer())
                .add(messageSerializer: VerackMessageSerializer())
                .add(messageSerializer: MempoolMessageSerializer())
                .add(messageSerializer: VersionMessageSerializer())
                .add(messageSerializer: TransactionMessageSerializer())
                .add(messageSerializer: FilterLoadMessageSerializer())

        bitcoinCore.add(peerGroupListener: bloomFilterLoader)
        bitcoinCore.add(peerTaskHandler: initialBlockDownload)
        bitcoinCore.add(inventoryItemsHandler: initialBlockDownload)
        bitcoinCore.add(peerGroupListener: initialBlockDownload)
        bitcoinCore.add(peerSyncListener: SendTransactionsOnPeerSynced(transactionSender: transactionSender))
        bitcoinCore.add(peerTaskHandler: mempoolTransactions)
        bitcoinCore.add(inventoryItemsHandler: mempoolTransactions)
        bitcoinCore.add(peerGroupListener: mempoolTransactions)

        return bitcoinCore
    }
}
