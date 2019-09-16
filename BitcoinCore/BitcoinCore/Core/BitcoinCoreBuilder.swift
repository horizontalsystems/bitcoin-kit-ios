import Foundation
import HSHDWalletKit

public class BitcoinCoreBuilder {
    public enum BuildError: Error { case noSeedData, noWalletId, noNetwork, noPaymentAddressParser, noAddressSelector, noStorage, noInitialSyncApi }

    // required parameters
    private var seed: Data?
    private var words: [String]?
    private var bip: Bip = .bip44
    private var network: INetwork?
    private var paymentAddressParser: IPaymentAddressParser?
    private var walletId: String?
    private var initialSyncApi: ISyncTransactionApi?
    private var logger: Logger

    private var blockHeaderHasher: IHasher?
    private var transactionInfoConverter: ITransactionInfoConverter?

    // parameters with default values
    private var confirmationsThreshold = 6
    private var syncMode = BitcoinCore.SyncMode.api
    private var peerCount = 10
    private var peerCountToConnect = 100

    private var storage: IStorage?

    public func set(seed: Data) -> BitcoinCoreBuilder {
        self.seed = seed
        return self
    }

    public func set(words: [String]) -> BitcoinCoreBuilder {
        self.words = words
        return self
    }

    public func set(bip: Bip) -> BitcoinCoreBuilder {
        self.bip = bip
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

    public func set(walletId: String) -> BitcoinCoreBuilder {
        self.walletId = walletId
        return self
    }

    public func set(confirmationsThreshold: Int) -> BitcoinCoreBuilder {
        self.confirmationsThreshold = confirmationsThreshold
        return self
    }

    public func set(syncMode: BitcoinCore.SyncMode) -> BitcoinCoreBuilder {
        self.syncMode = syncMode
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

    public func set(transactionInfoConverter: ITransactionInfoConverter) -> BitcoinCoreBuilder {
        self.transactionInfoConverter = transactionInfoConverter
        return self
    }

    public func set(initialSyncApi: ISyncTransactionApi?) -> BitcoinCoreBuilder {
        self.initialSyncApi = initialSyncApi
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
        guard let storage = self.storage else {
            throw BuildError.noStorage
        }
        guard let initialSyncApi = initialSyncApi else {
            throw BuildError.noInitialSyncApi
        }

        let addressConverter = AddressConverterChain()
        let restoreKeyConverterChain = RestoreKeyConverterChain()

//        let dbName = "bitcoinkit-${network.javaClass}-$walletId"
//        let database = KitDatabase.getInstance(context, dbName)
//        let realmFactory = RealmFactory(dbName)
//        let storage = Storage(database, realmFactory)
//
        let unspentOutputProvider = UnspentOutputProvider(storage: storage, confirmationsThreshold: confirmationsThreshold)
        let transactionInfoConverter = self.transactionInfoConverter ?? TransactionInfoConverter(baseTransactionInfoConverter: BaseTransactionInfoConverter())
        let dataProvider = DataProvider(storage: storage, unspentOutputProvider: unspentOutputProvider, transactionInfoConverter: transactionInfoConverter)

        let reachabilityManager = ReachabilityManager()

        let hdWallet = HDWallet(seed: seed, coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey, gapLimit: 20, purpose: bip.purpose)

        let networkMessageParser = NetworkMessageParser(magic: network.magic)
        let networkMessageSerializer = NetworkMessageSerializer(magic: network.magic)

        let doubleShaHasher = DoubleShaHasher()
        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)
        let merkleBlockValidator = MerkleBlockValidator(maxBlockSize: network.maxBlockSize, merkleBranch: merkleBranch)

        let factory = Factory(network: network, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer)

        let publicKeyManager = PublicKeyManager.instance(storage: storage, hdWallet: hdWallet, restoreKeyConverter: restoreKeyConverterChain)

        let myOutputsCache = OutputsCache.instance(storage: storage)
        let irregularOutputFinder = IrregularOutputFinder(storage: storage)
        let scriptConverter = ScriptConverter()
        let transactionInputExtractor = TransactionInputExtractor(storage: storage, scriptConverter: scriptConverter, addressConverter: addressConverter, logger: logger)
        let transactionKeySetter = TransactionPublicKeySetter(storage: storage)
        let transactionOutputExtractor = TransactionOutputExtractor(transactionKeySetter: transactionKeySetter, logger: logger)
        let transactionAddressExtractor = TransactionOutputAddressExtractor(storage: storage, addressConverter: addressConverter)
        let transactionProcessor = TransactionProcessor(storage: storage,
                outputExtractor: transactionOutputExtractor, inputExtractor: transactionInputExtractor,
                outputsCache: myOutputsCache, outputAddressExtractor: transactionAddressExtractor,
                addressManager: publicKeyManager, irregularOutputFinder: irregularOutputFinder, listener: dataProvider)

        let kitStateProvider = KitStateProvider()

        let peerDiscovery = PeerDiscovery()
        let peerAddressManager = PeerAddressManager(storage: storage, dnsSeeds: network.dnsSeeds, peerDiscovery: peerDiscovery, logger: logger)
        peerDiscovery.peerAddressManager = peerAddressManager
        let bloomFilterManager = BloomFilterManager(factory: factory)

        let peerManager = PeerManager()
        let unspentOutputSelector = UnspentOutputSelectorChain()
        let transactionSyncer = TransactionSyncer(storage: storage, processor: transactionProcessor, publicKeyManager: publicKeyManager)
        let mempoolTransactions = MempoolTransactions(transactionSyncer: transactionSyncer)

        let blockHashFetcher = BlockHashFetcher(restoreKeyConverter: restoreKeyConverterChain, apiManager: initialSyncApi, helper: BlockHashFetcherHelper())
        let blockDiscovery = BlockDiscoveryBatch(network: network, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        let stateManager = StateManager(storage: storage, restoreFromApi: network.syncableFromApi && syncMode == BitcoinCore.SyncMode.api)

        let initialSyncer = InitialSyncer(storage: storage, listener: kitStateProvider, stateManager: stateManager, blockDiscovery: blockDiscovery, publicKeyManager: publicKeyManager, logger: logger)

        let bloomFilterLoader = BloomFilterLoader(bloomFilterManager: bloomFilterManager, peerManager: peerManager)
        let watchedTransactionManager = WatchedTransactionManager()

        let blockValidatorChain = BlockValidatorChain(proofOfWorkValidator: ProofOfWorkValidator(difficultyEncoder: DifficultyEncoder()))
        let blockchain = Blockchain(storage: storage, blockValidator: blockValidatorChain, factory: factory, listener: dataProvider)
        let checkpointBlock = BlockSyncer.checkpointBlock(network: network, syncMode: syncMode, storage: storage)
        let blockSyncer = BlockSyncer.instance(storage: storage, checkpointBlock: checkpointBlock, factory: factory, listener: kitStateProvider, transactionProcessor: transactionProcessor, blockchain: blockchain, publicKeyManager: publicKeyManager, logger: logger)
        let initialBlockDownload = InitialBlockDownload(blockSyncer: blockSyncer, peerManager: peerManager, merkleBlockValidator: merkleBlockValidator, syncStateListener: kitStateProvider, logger: logger)

        let peerGroup = PeerGroup(factory: factory, reachabilityManager: reachabilityManager,
                peerAddressManager: peerAddressManager, peerCount: peerCount, localDownloadedBestBlockHeight: blockSyncer.localDownloadedBestBlockHeight,
                peerManager: peerManager, logger: logger)
        let syncedReadyPeerManager = SyncedReadyPeerManager(peerGroup: peerGroup, initialBlockDownload: initialBlockDownload)

        let inputSigner = InputSigner(hdWallet: hdWallet, network: network)
        let scriptBuilder = ScriptBuilderChain()
        let transactionSizeCalculator = TransactionSizeCalculator()
        let transactionBuilder = TransactionBuilder(inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        let transactionFeeCalculator = TransactionFeeCalculator(unspentOutputSelector: unspentOutputSelector, transactionSizeCalculator: transactionSizeCalculator)
        let transactionSender = TransactionSender(transactionSyncer: transactionSyncer, peerManager: peerManager, initialBlockDownload: initialBlockDownload, syncedReadyPeerManager: syncedReadyPeerManager, logger: logger)
        let transactionCreator = TransactionCreator(transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, transactionSender: transactionSender, transactionFeeCalculator: transactionFeeCalculator,
                bloomFilterManager: bloomFilterManager, addressConverter: addressConverter, publicKeyManager: publicKeyManager, storage: storage, bip: bip)

        let syncManager = SyncManager(reachabilityManager: reachabilityManager, initialSyncer: initialSyncer, peerGroup: peerGroup)

        let bitcoinCore = BitcoinCore(storage: storage,
                cache: myOutputsCache,
                dataProvider: dataProvider,
                peerGroup: peerGroup,
                initialBlockDownload: initialBlockDownload,
                bloomFilterLoader: bloomFilterLoader,
                syncedReadyPeerManager: syncedReadyPeerManager,
                transactionSyncer: transactionSyncer,
                blockValidatorChain: blockValidatorChain,
                publicKeyManager: publicKeyManager,
                addressConverter: addressConverter,
                restoreKeyConverterChain: restoreKeyConverterChain,
                unspentOutputSelector: unspentOutputSelector,
                kitStateProvider: kitStateProvider,
                scriptBuilder: scriptBuilder,
                transactionCreator: transactionCreator,
                transactionFeeCalculator: transactionFeeCalculator,
                paymentAddressParser: paymentAddressParser,
                networkMessageParser: networkMessageParser,
                networkMessageSerializer: networkMessageSerializer,
                syncManager: syncManager,
                watchedTransactionManager: watchedTransactionManager,
                bip: bip)

        initialSyncer.delegate = syncManager
        bloomFilterManager.delegate = bloomFilterLoader
        dataProvider.delegate = bitcoinCore
        kitStateProvider.delegate = bitcoinCore
        transactionProcessor.transactionListener = watchedTransactionManager

        bloomFilterManager.add(provider: watchedTransactionManager)
        bloomFilterManager.add(provider: publicKeyManager)
        bloomFilterManager.add(provider: irregularOutputFinder)

        peerGroup.peerTaskHandler = bitcoinCore.peerTaskHandlerChain
        peerGroup.inventoryItemsHandler = bitcoinCore.inventoryItemsHandlerChain

        bitcoinCore.prepend(scriptBuilder: ScriptBuilder())
        bitcoinCore.prepend(addressConverter: Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelector(calculator: transactionSizeCalculator, provider: unspentOutputProvider))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelectorSingleNoChange(calculator: transactionSizeCalculator, provider: unspentOutputProvider))
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

        bloomFilterLoader.subscribeTo(observable: peerGroup.observable)
        initialBlockDownload.subscribeTo(observable: peerGroup.observable)
        syncedReadyPeerManager.subscribeTo(observable: peerGroup.observable)
        mempoolTransactions.subscribeTo(observable: peerGroup.observable)


        bitcoinCore.add(peerTaskHandler: initialBlockDownload)
        bitcoinCore.add(inventoryItemsHandler: initialBlockDownload)

        syncedReadyPeerManager.subscribeTo(observable: initialBlockDownload.observable)
        transactionSender.subscribeTo(observable: syncedReadyPeerManager.observable)


        bitcoinCore.add(peerTaskHandler: mempoolTransactions)
        bitcoinCore.add(inventoryItemsHandler: mempoolTransactions)

        return bitcoinCore
    }
}
