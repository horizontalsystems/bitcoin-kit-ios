import Foundation
import HSHDWalletKit

class BitcoinCoreBuilder {
    enum BuildError: Error { case noSeedData, noWalletId, noNetwork, noPaymentAddressParser, noAddressSelector, noFeeRateApiResource, noStorage }

    // required parameters
    private var seed: Data?
    private var words: [String]?
    private var network: INetwork?
    private var paymentAddressParser: IPaymentAddressParser?
    private var addressSelector: IAddressSelector?
    private var feeRateApiResource: String?
    private var walletId: String?

    // parameters with default values
    private var confirmationsThreshold = 6
    private var newWallet = false
    private var peerCount = 10

    private var storage: IStorage?

    func set(seed: Data) -> BitcoinCoreBuilder {
        self.seed = seed
        return self
    }

    func set(words: [String]) -> BitcoinCoreBuilder {
        self.words = words
        return self
    }

    func set(network: INetwork) -> BitcoinCoreBuilder {
        self.network = network
        return self
    }

    func set(paymentAddressParser: PaymentAddressParser) -> BitcoinCoreBuilder {
        self.paymentAddressParser = paymentAddressParser
        return self
    }

    func set(addressSelector: IAddressSelector) -> BitcoinCoreBuilder {
        self.addressSelector = addressSelector
        return self
    }

    func set(feeRateApiResource: String) -> BitcoinCoreBuilder {
        self.feeRateApiResource = feeRateApiResource
        return self
    }

    func set(walletId: String) -> BitcoinCoreBuilder {
        self.walletId = walletId
        return self
    }

    func set(confirmationsThreshold: Int) -> BitcoinCoreBuilder {
        self.confirmationsThreshold = confirmationsThreshold
        return self
    }

    func set(newWallet: Bool) -> BitcoinCoreBuilder {
        self.newWallet = newWallet
        return self
    }

    func set(peerSize: Int) -> BitcoinCoreBuilder {
        self.peerCount = peerSize
        return self
    }

    func set(storage: IStorage) -> BitcoinCoreBuilder {
        self.storage = storage
        return self
    }

    func build() throws -> BitcoinCore {
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
        guard let feeRateApiResource = self.feeRateApiResource else {
            throw BuildError.noFeeRateApiResource
        }
        guard let storage = self.storage else {
            throw BuildError.noStorage
        }

        let logger = Logger(network: network, minLogLevel: .verbose)

        let apiFeeRate = IpfsApi(resource: feeRateApiResource, apiProvider: FeeRateApiProvider(), logger: logger)
        let feeRateSyncer = FeeRateSyncer(api: apiFeeRate, storage: storage)

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

        let hasher = MerkleRootHasher()
        let merkleBranch = MerkleBranch(hasher: hasher)
        let merkleBlockValidator = MerkleBlockValidator(maxBlockSize: network.maxBlockSize, merkleBranch: merkleBranch)

        let factory = Factory(network: network, networkMessageParser: networkMessageParser, networkMessageSerializer: networkMessageSerializer, merkleBlockValidator: merkleBlockValidator)

        let addressManager = AddressManager.instance(storage: storage, hdWallet: hdWallet, addressConverter: addressConverter)

        let transactionLinker = TransactionLinker(storage: storage)
        let scriptConverter = ScriptConverter()
        let transactionInputExtractor = TransactionInputExtractor(storage: storage, scriptConverter: scriptConverter, addressConverter: addressConverter, logger: logger)
        let transactionKeySetter = TransactionPublicKeySetter(storage: storage)
        let transactionOutputExtractor = TransactionOutputExtractor(transactionKeySetter: transactionKeySetter, logger: logger)
        let transactionAddressExtractor = TransactionOutputAddressExtractor(storage: storage, addressConverter: addressConverter)
        let transactionProcessor = TransactionProcessor(storage: storage,
                outputExtractor: transactionOutputExtractor, inputExtractor: transactionInputExtractor,
                linker: transactionLinker, outputAddressExtractor: transactionAddressExtractor,
                addressManager: addressManager, listener: dataProvider)

        let kitStateProvider = KitStateProvider()

        let peerDiscovery = PeerDiscovery()
        let peerAddressManager = PeerAddressManager(storage: storage, dnsSeeds: network.dnsSeeds, peerDiscovery: peerDiscovery, logger: logger)
        peerDiscovery.peerAddressManager = peerAddressManager
        let bloomFilterManager = BloomFilterManager(storage: storage, factory: factory)

        let peerManager = PeerManager()


        let peerGroup = PeerGroup(factory: factory, reachabilityManager: reachabilityManager,
                peerAddressManager: peerAddressManager, peerCount: peerCount, peerManager: peerManager, logger: logger)

        let transactionSizeCalculator = TransactionSizeCalculator()
        let unspentOutputSelector = UnspentOutputSelector(calculator: transactionSizeCalculator)
        let transactionSyncer = TransactionSyncer(storage: storage, processor: transactionProcessor, addressManager: addressManager, bloomFilterManager: bloomFilterManager)

        let transactionSender = TransactionSender(transactionSyncer: transactionSyncer, peerGroup: peerGroup, logger: logger)

        let scriptBuilder = ScriptBuilder()
        let inputSigner = InputSigner(hdWallet: hdWallet, network: network)

        let transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, addressManager: addressManager, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        let transactionCreator = TransactionCreator(transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, transactionSender: transactionSender)

        let blockHashFetcher = BlockHashFetcher(addressSelector: addressSelector, apiManager: BCoinApi(network: network), addressConverter: addressConverter, helper: BlockHashFetcherHelper())
        let blockDiscovery = BlockDiscoveryBatch(network: network, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        let stateManager = StateManager(storage: storage, network: network, newWallet: newWallet)

        let initialSyncer = InitialSyncer(storage: storage, listener: kitStateProvider, stateManager: stateManager, blockDiscovery: blockDiscovery, addressManager: addressManager, logger: logger)

        let syncManager = SyncManager(reachabilityManager: reachabilityManager, feeRateSyncer: feeRateSyncer, initialSyncer: initialSyncer, peerGroup: peerGroup)
        initialSyncer.delegate = syncManager

        let bitcoinCore = BitcoinCore(storage: storage,
                dataProvider: dataProvider,
                peerGroup: peerGroup,
                transactionSyncer: transactionSyncer,
                addressManager: addressManager,
                addressConverter: addressConverter,
                kitStateProvider: kitStateProvider,
                transactionBuilder: transactionBuilder,
                transactionCreator: transactionCreator,
                paymentAddressParser: paymentAddressParser,
                networkMessageParser: networkMessageParser,
                networkMessageSerializer: networkMessageSerializer,
                syncManager: syncManager)

        dataProvider.delegate = bitcoinCore
        kitStateProvider.delegate = bitcoinCore

        bitcoinCore.peerGroup = peerGroup
        bitcoinCore.transactionSyncer = transactionSyncer

        peerGroup.peerTaskHandler = bitcoinCore.peerTaskHandlerChain
        peerGroup.inventoryItemsHandler = bitcoinCore.inventoryItemsHandlerChain

        bitcoinCore.prepend(addressConverter: Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash))

        // this part can be moved to another place

        let messageParsersConfigurator = NetworkMessageConfiguration(network: network)
        bitcoinCore.add(messageParsers: messageParsersConfigurator.networkMessageParsers)
        bitcoinCore.add(messageSerializers: messageParsersConfigurator.networkMessageSerializers)

        let bloomFilterLoader = BloomFilterLoader(bloomFilterManager: bloomFilterManager)
        bloomFilterManager.delegate = bloomFilterLoader
        bitcoinCore.add(peerGroupListener: bloomFilterLoader)

        let blockchain = Blockchain(storage: storage, blockValidator: bitcoinCore.blockValidatorChain, factory: factory, listener: dataProvider)
        let blockSyncer = BlockSyncer.instance(storage: storage, network: network, factory: factory, listener: kitStateProvider, transactionProcessor: transactionProcessor, blockchain: blockchain, addressManager: addressManager, bloomFilterManager: bloomFilterManager, logger: logger)
        let initialBlockDownload = InitialBlockDownload(blockSyncer: blockSyncer, peerManager: peerManager, syncStateListener: kitStateProvider, logger: logger)

        bitcoinCore.add(peerTaskHandler: initialBlockDownload)
        bitcoinCore.add(inventoryItemsHandler: initialBlockDownload)
        bitcoinCore.add(peerGroupListener: initialBlockDownload)
        initialBlockDownload.peerSyncedDelegate = SendTransactionsOnPeerSynced(transactionSender: transactionSender)

        let mempoolTransactions = MempoolTransactions(transactionSyncer: transactionSyncer)

        bitcoinCore.add(peerTaskHandler: mempoolTransactions)
        bitcoinCore.add(inventoryItemsHandler: mempoolTransactions)
        bitcoinCore.add(peerGroupListener: mempoolTransactions)

        return bitcoinCore
    }
}
