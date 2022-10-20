import Foundation
import HdWalletKit
import HsToolKit

public class BitcoinCoreBuilder {
    public enum BuildError: Error { case peerSizeLessThanRequired, noSeedData, noWalletId, noNetwork, noPaymentAddressParser, noAddressSelector, noStorage, noInitialSyncApi }

    // chains
    public let addressConverter = AddressConverterChain()

    // required parameters
    private var seed: Data?
    private var bip: Bip = .bip44
    private var network: INetwork?
    private var paymentAddressParser: IPaymentAddressParser?
    private var walletId: String?
    private var initialSyncApi: ISyncTransactionApi?
    private var plugins = [IPlugin]()
    private var logger: Logger

    private var blockHeaderHasher: IHasher?
    private var blockValidator: IBlockValidator?
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

    public func set(peerSize: Int) throws -> BitcoinCoreBuilder {
        guard peerSize >= TransactionSender.minConnectedPeersCount else {
            throw BuildError.peerSizeLessThanRequired
        }

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

    public func set(blockValidator: IBlockValidator) -> BitcoinCoreBuilder {
        self.blockValidator = blockValidator
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

    public func add(plugin: IPlugin) -> BitcoinCoreBuilder {
        plugins.append(plugin)
        return self
    }

    public init(logger: Logger) {
        self.logger = logger
    }

    public func build() throws -> BitcoinCore {
        let seed: Data
        if let selfSeed = self.seed {
           seed = selfSeed
        } else {
            throw BuildError.noSeedData
        }
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

        let scriptConverter = ScriptConverter()
        let restoreKeyConverterChain = RestoreKeyConverterChain()
        let pluginManager = PluginManager(scriptConverter: scriptConverter, logger: logger)

        plugins.forEach { pluginManager.add(plugin: $0) }
        restoreKeyConverterChain.add(converter: pluginManager)

        let unspentOutputProvider = UnspentOutputProvider(storage: storage, pluginManager: pluginManager, confirmationsThreshold: confirmationsThreshold)
        var transactionInfoConverter = self.transactionInfoConverter ?? TransactionInfoConverter()
        transactionInfoConverter.baseTransactionInfoConverter = BaseTransactionInfoConverter(pluginManager: pluginManager)
        let dataProvider = DataProvider(storage: storage, balanceProvider: unspentOutputProvider, transactionInfoConverter: transactionInfoConverter)

        let reachabilityManager = ReachabilityManager()

        let hdWallet = HDWallet(seed: seed, coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey, gapLimit: 20, purpose: bip.purpose)

        let networkMessageParser = NetworkMessageParser(magic: network.magic)
        let networkMessageSerializer = NetworkMessageSerializer(magic: network.magic)

        let doubleShaHasher = DoubleShaHasher()
        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)
        let merkleBlockValidator = MerkleBlockValidator(maxBlockSize: network.maxBlockSize, merkleBranch: merkleBranch)

        let factory = Factory(network: network, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer)

        let publicKeyManager = PublicKeyManager.instance(storage: storage, hdWallet: hdWallet, restoreKeyConverter: restoreKeyConverterChain)
        let pendingOutpointsProvider = PendingOutpointsProvider(storage: storage)

        let transactionMetadataExtractor = TransactionMetadataExtractor(storage: storage)
        let irregularOutputFinder = IrregularOutputFinder(storage: storage)
        let transactionInputExtractor = TransactionInputExtractor(storage: storage, scriptConverter: scriptConverter, addressConverter: addressConverter, logger: logger)
        let transactionKeySetter = TransactionPublicKeySetter(storage: storage)
        let transactionOutputExtractor = TransactionOutputExtractor(transactionKeySetter: transactionKeySetter, pluginManager: pluginManager, logger: logger)
        let transactionAddressExtractor = TransactionOutputAddressExtractor(storage: storage, addressConverter: addressConverter)
        let transactionExtractor = TransactionExtractor(outputExtractor: transactionOutputExtractor, inputExtractor: transactionInputExtractor, metaDataExtractor: transactionMetadataExtractor, outputAddressExtractor: transactionAddressExtractor)
        let transactionInvalidator = TransactionInvalidator(storage: storage, transactionInfoConverter: transactionInfoConverter, listener: dataProvider)
        let transactionConflictResolver = TransactionConflictsResolver(storage: storage)
        let transactionsProcessorQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.transaction-processor", qos: .background)
        let blockTransactionProcessor = BlockTransactionProcessor(storage: storage, extractor: transactionExtractor, publicKeyManager: publicKeyManager, irregularOutputFinder: irregularOutputFinder, conflictsResolver: transactionConflictResolver, invalidator: transactionInvalidator, listener: dataProvider, queue: transactionsProcessorQueue)
        let pendingTransactionProcessor = PendingTransactionProcessor(storage: storage, extractor: transactionExtractor, publicKeyManager: publicKeyManager, irregularOutputFinder: irregularOutputFinder, conflictsResolver: transactionConflictResolver, listener: dataProvider, queue: transactionsProcessorQueue)

        let peerDiscovery = PeerDiscovery()
        let peerAddressManager = PeerAddressManager(storage: storage, dnsSeeds: network.dnsSeeds, peerDiscovery: peerDiscovery, logger: logger)
        peerDiscovery.peerAddressManager = peerAddressManager
        let bloomFilterManager = BloomFilterManager(factory: factory)

        let peerManager = PeerManager()
        let unspentOutputSelector = UnspentOutputSelectorChain()
        let transactionSyncer = TransactionSyncer(storage: storage, processor: pendingTransactionProcessor, invalidator: transactionInvalidator, publicKeyManager: publicKeyManager)

        let checkpoint = BlockSyncer.resolveCheckpoint(network: network, syncMode: syncMode, storage: storage)

        let blockHashFetcher = BlockHashFetcher(restoreKeyConverter: restoreKeyConverterChain, apiManager: initialSyncApi, helper: BlockHashFetcherHelper())
        let blockDiscovery = BlockDiscoveryBatch(checkpoint: checkpoint, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        let stateManager = ApiSyncStateManager(storage: storage, restoreFromApi: network.syncableFromApi && syncMode == BitcoinCore.SyncMode.api)

        let initialSyncer = InitialSyncer(storage: storage, blockDiscovery: blockDiscovery, publicKeyManager: publicKeyManager, logger: logger)

        let bloomFilterLoader = BloomFilterLoader(bloomFilterManager: bloomFilterManager, peerManager: peerManager)
        let watchedTransactionManager = WatchedTransactionManager()

        let blockchain = Blockchain(storage: storage, blockValidator: blockValidator, factory: factory, listener: dataProvider)
        let blockSyncer = BlockSyncer.instance(storage: storage, checkpoint: checkpoint, factory: factory, transactionProcessor: blockTransactionProcessor, blockchain: blockchain, publicKeyManager: publicKeyManager, logger: logger)
        let initialBlockDownload = InitialBlockDownload(blockSyncer: blockSyncer, peerManager: peerManager, merkleBlockValidator: merkleBlockValidator, logger: logger)

        let peerGroup = PeerGroup(factory: factory, reachabilityManager: reachabilityManager,
                peerAddressManager: peerAddressManager, peerCount: peerCount, localDownloadedBestBlockHeight: blockSyncer.localDownloadedBestBlockHeight,
                peerManager: peerManager, logger: logger)

        let transactionDataSorterFactory = TransactionDataSorterFactory()

        let inputSigner = InputSigner(hdWallet: hdWallet, network: network)
        let transactionSizeCalculator = TransactionSizeCalculator()
        let dustCalculator = DustCalculator(dustRelayTxFee: network.dustRelayTxFee, sizeCalculator: transactionSizeCalculator)
        let recipientSetter = RecipientSetter(addressConverter: addressConverter, pluginManager: pluginManager)
        let outputSetter = OutputSetter(outputSorterFactory: transactionDataSorterFactory, factory: factory)
        let inputSetter = InputSetter(unspentOutputSelector: unspentOutputSelector, transactionSizeCalculator: transactionSizeCalculator, addressConverter: addressConverter, publicKeyManager: publicKeyManager, factory: factory, pluginManager: pluginManager, dustCalculator: dustCalculator, changeScriptType: bip.scriptType, inputSorterFactory: transactionDataSorterFactory)
        let lockTimeSetter = LockTimeSetter(storage: storage)
        let transactionSigner = TransactionSigner(inputSigner: inputSigner)
        let transactionBuilder = TransactionBuilder(recipientSetter: recipientSetter, inputSetter: inputSetter, lockTimeSetter: lockTimeSetter, outputSetter: outputSetter, signer: transactionSigner)
        let transactionFeeCalculator = TransactionFeeCalculator(recipientSetter: recipientSetter, inputSetter: inputSetter, addressConverter: addressConverter, publicKeyManager: publicKeyManager, changeScriptType: bip.scriptType)
        let transactionSendTimer = TransactionSendTimer(interval: 60)
        let transactionSender = TransactionSender(transactionSyncer: transactionSyncer, initialBlockDownload: initialBlockDownload, peerManager: peerManager, storage: storage, timer: transactionSendTimer, logger: logger)
        let transactionCreator = TransactionCreator(transactionBuilder: transactionBuilder, transactionProcessor: pendingTransactionProcessor, transactionSender: transactionSender, bloomFilterManager: bloomFilterManager)
        let mempoolTransactions = MempoolTransactions(transactionSyncer: transactionSyncer, transactionSender: transactionSender)

        let syncManager = SyncManager(reachabilityManager: reachabilityManager, initialSyncer: initialSyncer, peerGroup: peerGroup, apiSyncStateManager: stateManager, bestBlockHeight: blockSyncer.localDownloadedBestBlockHeight)

        let bitcoinCore = BitcoinCore(storage: storage,
                dataProvider: dataProvider,
                peerGroup: peerGroup,
                initialBlockDownload: initialBlockDownload,
                bloomFilterLoader: bloomFilterLoader,
                transactionSyncer: transactionSyncer,
                publicKeyManager: publicKeyManager,
                addressConverter: addressConverter,
                restoreKeyConverterChain: restoreKeyConverterChain,
                unspentOutputSelector: unspentOutputSelector,
                transactionCreator: transactionCreator,
                transactionFeeCalculator: transactionFeeCalculator,
                dustCalculator: dustCalculator,
                paymentAddressParser: paymentAddressParser,
                networkMessageParser: networkMessageParser,
                networkMessageSerializer: networkMessageSerializer,
                syncManager: syncManager,
                pluginManager: pluginManager,
                watchedTransactionManager: watchedTransactionManager,
                bip: bip,
                peerManager: peerManager)

        initialSyncer.delegate = syncManager
        blockSyncer.listener = syncManager
        initialBlockDownload.listener = syncManager
        blockHashFetcher.listener = syncManager

        bloomFilterManager.delegate = bloomFilterLoader
        dataProvider.delegate = bitcoinCore
        syncManager.delegate = bitcoinCore
        blockTransactionProcessor.transactionListener = watchedTransactionManager
        pendingTransactionProcessor.transactionListener = watchedTransactionManager
        transactionSendTimer.delegate = transactionSender

        bloomFilterManager.add(provider: watchedTransactionManager)
        bloomFilterManager.add(provider: publicKeyManager)
        bloomFilterManager.add(provider: pendingOutpointsProvider)
        bloomFilterManager.add(provider: irregularOutputFinder)

        peerGroup.peerTaskHandler = bitcoinCore.peerTaskHandlerChain
        peerGroup.inventoryItemsHandler = bitcoinCore.inventoryItemsHandlerChain

        bitcoinCore.prepend(addressConverter: Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelector(calculator: transactionSizeCalculator, provider: unspentOutputProvider, dustCalculator: dustCalculator))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelectorSingleNoChange(calculator: transactionSizeCalculator, provider: unspentOutputProvider, dustCalculator: dustCalculator))
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
        mempoolTransactions.subscribeTo(observable: peerGroup.observable)

        bitcoinCore.add(peerTaskHandler: initialBlockDownload)
        bitcoinCore.add(inventoryItemsHandler: initialBlockDownload)

        transactionSender.subscribeTo(observable: initialBlockDownload.observable)

        bitcoinCore.add(peerTaskHandler: transactionSender)
        bitcoinCore.add(peerTaskHandler: mempoolTransactions)
        bitcoinCore.add(inventoryItemsHandler: mempoolTransactions)

        return bitcoinCore
    }
}
