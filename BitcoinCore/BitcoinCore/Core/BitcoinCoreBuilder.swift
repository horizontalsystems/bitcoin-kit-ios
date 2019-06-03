import Foundation
import HSHDWalletKit

public class BitcoinCoreBuilder {
    public enum BuildError: Error { case noSeedData, noWalletId, noNetwork, noPaymentAddressParser, noAddressSelector, noStorage, noInitialSyncApi }

    // required parameters
    private var seed: Data?
    private var words: [String]?
    private var network: INetwork?
    private var paymentAddressParser: IPaymentAddressParser?
    private var addressSelector: IAddressSelector?
    private var addressKeyHashConverter: IAddressKeyHashConverter?
    private var walletId: String?
    private var initialSyncApi: ISyncTransactionApi?
    private var logger: Logger

    private var blockHeaderHasher: IHasher?
    private var transactionInfoConverter: ITransactionInfoConverter?

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

    public func set(addressKeyHashConverter: IAddressKeyHashConverter) -> BitcoinCoreBuilder {
        self.addressKeyHashConverter = addressKeyHashConverter
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
        guard let addressSelector = self.addressSelector else {
            throw BuildError.noAddressSelector
        }
        guard let storage = self.storage else {
            throw BuildError.noStorage
        }
        guard let initialSyncApi = initialSyncApi else {
            throw BuildError.noInitialSyncApi
        }

        let addressConverter = AddressConverterChain()

//        let dbName = "bitcoinkit-${network.javaClass}-$walletId"
//        let database = KitDatabase.getInstance(context, dbName)
//        let realmFactory = RealmFactory(dbName)
//        let storage = Storage(database, realmFactory)
//
        let unspentOutputProvider = UnspentOutputProvider(storage: storage, confirmationsThreshold: confirmationsThreshold)
        let transactionInfoConverter = self.transactionInfoConverter ?? TransactionInfoConverter(baseTransactionInfoConverter: BaseTransactionInfoConverter())
        let dataProvider = DataProvider(storage: storage, unspentOutputProvider: unspentOutputProvider, transactionInfoConverter: transactionInfoConverter)

        let reachabilityManager = ReachabilityManager()

        let hdWallet = HDWallet(seed: seed, coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey, gapLimit: 20)

        let networkMessageParser = NetworkMessageParser(magic: network.magic)
        let networkMessageSerializer = NetworkMessageSerializer(magic: network.magic)

        let doubleShaHasher = DoubleShaHasher()
        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)
        let merkleBlockValidator = MerkleBlockValidator(maxBlockSize: network.maxBlockSize, merkleBranch: merkleBranch)

        let factory = Factory(network: network, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer)

        let addressManager = AddressManager.instance(storage: storage, hdWallet: hdWallet, addressConverter: addressConverter, addressKeyHashConverter: addressKeyHashConverter)

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

        let unspentOutputSelector = UnspentOutputSelectorChain()
        let transactionSyncer = TransactionSyncer(storage: storage, processor: transactionProcessor, addressManager: addressManager, bloomFilterManager: bloomFilterManager)
        let mempoolTransactions = MempoolTransactions(transactionSyncer: transactionSyncer)

        let blockHashFetcher = BlockHashFetcher(addressSelector: addressSelector, apiManager: initialSyncApi, addressConverter: addressConverter, helper: BlockHashFetcherHelper())
        let blockDiscovery = BlockDiscoveryBatch(network: network, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        let stateManager = StateManager(storage: storage, network: network, newWallet: newWallet)

        let initialSyncer = InitialSyncer(storage: storage, listener: kitStateProvider, stateManager: stateManager, blockDiscovery: blockDiscovery, addressManager: addressManager, logger: logger)

        let syncManager = SyncManager(reachabilityManager: reachabilityManager, initialSyncer: initialSyncer, peerGroup: peerGroup)

        let bloomFilterLoader = BloomFilterLoader(bloomFilterManager: bloomFilterManager, peerManager: peerManager)

        let blockValidatorChain = BlockValidatorChain(proofOfWorkValidator: ProofOfWorkValidator(difficultyEncoder: DifficultyEncoder()))
        let blockchain = Blockchain(storage: storage, blockValidator: blockValidatorChain, factory: factory, listener: dataProvider)
        let blockSyncer = BlockSyncer.instance(storage: storage, network: network, factory: factory, listener: kitStateProvider, transactionProcessor: transactionProcessor, blockchain: blockchain, addressManager: addressManager, bloomFilterManager: bloomFilterManager, logger: logger)
        let initialBlockDownload = InitialBlockDownload(blockSyncer: blockSyncer, peerManager: peerManager, merkleBlockValidator: merkleBlockValidator, syncStateListener: kitStateProvider, logger: logger)
        let syncedReadyPeerManager = SyncedReadyPeerManager(peerGroup: peerGroup, initialBlockDownload: initialBlockDownload)

        let inputSigner = InputSigner(hdWallet: hdWallet, network: network)
        let scriptBuilder = ScriptBuilderChain()
        let transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, addressManager: addressManager, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        let transactionSender = TransactionSender(transactionSyncer: transactionSyncer, peerManager: peerManager, initialBlockDownload: initialBlockDownload, syncedReadyPeerManager: syncedReadyPeerManager, logger: logger)
        let transactionCreator = TransactionCreator(transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, transactionSender: transactionSender)


        let bitcoinCore = BitcoinCore(storage: storage,
                cache: myOutputsCache,
                dataProvider: dataProvider,
                peerGroup: peerGroup,
                initialBlockDownload: initialBlockDownload,
                bloomFilterLoader: bloomFilterLoader,
                syncedReadyPeerManager: syncedReadyPeerManager,
                transactionSyncer: transactionSyncer,
                blockValidatorChain: blockValidatorChain,
                addressManager: addressManager,
                addressConverter: addressConverter,
                unspentOutputSelector: unspentOutputSelector,
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

        peerGroup.peerTaskHandler = bitcoinCore.peerTaskHandlerChain
        peerGroup.inventoryItemsHandler = bitcoinCore.inventoryItemsHandlerChain

        bitcoinCore.prepend(scriptBuilder: ScriptBuilder())
        bitcoinCore.prepend(addressConverter: Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash))

        let transactionSizeCalculator = TransactionSizeCalculator()
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
