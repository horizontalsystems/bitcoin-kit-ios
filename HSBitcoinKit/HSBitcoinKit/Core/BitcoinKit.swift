import Foundation
import HSHDWalletKit
import RealmSwift
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinKit {

    public weak var delegate: BitcoinKitDelegate?
    public var delegateQueue = DispatchQueue(label: "bitcoin_delegate_queue")

    private var unspentOutputsNotificationToken: NotificationToken?
    private var transactionsNotificationToken: NotificationToken?
    private var blocksNotificationToken: NotificationToken?

    private let difficultyEncoder: IDifficultyEncoder
    private let blockHelper: IBlockHelper
    private let validatorFactory: IBlockValidatorFactory

    private let network: INetwork
    private let logger: Logger

    private let realmFactory: IRealmFactory

    private let hdWallet: IHDWallet

    private let bcoinReachabilityManager: ReachabilityManager

    private let reachabilityManager: ReachabilityManager
    private let peerAddressManager: IPeerAddressManager
    private let stateManager: IStateManager

    private let blockDiscovery: IBlockDiscovery

    private let ipfsApi: IFeeRateApi
    private let addressManager: IAddressManager
    private let bloomFilterManager: IBloomFilterManager

    private var peerGroup: IPeerGroup
    private let factory: IFactory

    private var initialSyncer: IInitialSyncer

    private let storage: IStorage

    private let feeRateApiProvider: IApiConfigProvider
    private let feeRateSyncer: FeeRateSyncer

    private let paymentAddressParser: IPaymentAddressParser
    private let bech32AddressConverter: IBech32AddressConverter
    private let addressConverter: IAddressConverter
    private let scriptConverter: IScriptConverter
    private let transactionProcessor: ITransactionProcessor
    private let transactionOutputExtractor: ITransactionExtractor
    private let transactionInputExtractor: ITransactionExtractor
    private let transactionOutputAddressExtractor: ITransactionOutputAddressExtractor
    private let transactionPublicKeySetter: ITransactionPublicKeySetter
    private let transactionLinker: ITransactionLinker
    private let transactionSyncer: ITransactionSyncer
    private let transactionCreator: ITransactionCreator
    private let transactionBuilder: ITransactionBuilder
    private let blockchain: IBlockchain

    private let inputSigner: IInputSigner
    private let scriptBuilder: IScriptBuilder
    private let transactionSizeCalculator: ITransactionSizeCalculator
    private let unspentOutputSelector: IUnspentOutputSelector
    private let unspentOutputProvider: IUnspentOutputProvider

    private let blockSyncer: IBlockSyncer

    private let syncManager: SyncManager

    private let kitStateProvider: IKitStateProvider & ISyncStateListener
    private var dataProvider: IDataProvider & IBlockchainDataListener

    public init(withWords words: [String], coin: Coin, walletId: String, newWallet: Bool = false, confirmationsThreshold: Int = 6, minLogLevel: Logger.Level = .verbose) {
        let databaseFileName = "\(walletId)-\(coin.rawValue)"

        realmFactory = RealmFactory(realmFileName: "\(databaseFileName).realm")
        storage = GrdbStorage(databaseFileName: databaseFileName, realmFactory: realmFactory)

        difficultyEncoder = DifficultyEncoder()
        blockHelper = BlockHelper()
        validatorFactory = BlockValidatorFactory(difficultyEncoder: difficultyEncoder, blockHelper: blockHelper)

        scriptConverter = ScriptConverter()
        switch coin {
        case .bitcoin(let networkType):
            switch networkType {
            case .mainNet:
                network = BitcoinMainNet(validatorFactory: validatorFactory)
                bech32AddressConverter = SegWitBech32AddressConverter(scriptConverter: scriptConverter)
                paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
            case .testNet:
                network = BitcoinTestNet(validatorFactory: validatorFactory)
                bech32AddressConverter = SegWitBech32AddressConverter(scriptConverter: scriptConverter)
                paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
            case .regTest:
                network = BitcoinRegTest(validatorFactory: validatorFactory)
                bech32AddressConverter = SegWitBech32AddressConverter(scriptConverter: scriptConverter)
                paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
            }
        case .bitcoinCash(let networkType):
            switch networkType {
            case .mainNet:
                network = BitcoinCashMainNet(validatorFactory: validatorFactory, blockHelper: blockHelper)
                bech32AddressConverter = CashBech32AddressConverter()
                paymentAddressParser = PaymentAddressParser(validScheme: "bitcoincash", removeScheme: false)
            case .testNet, .regTest:
                network = BitcoinCashTestNet(validatorFactory: validatorFactory)
                bech32AddressConverter = CashBech32AddressConverter()
                paymentAddressParser = PaymentAddressParser(validScheme: "bitcoincash", removeScheme: false)
            }
        }
        addressConverter = AddressConverter(network: network, bech32AddressConverter: bech32AddressConverter)
        logger = Logger(network: network, minLogLevel: minLogLevel)

        hdWallet = HDWallet(seed: Mnemonic.seed(mnemonic: words), coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey, gapLimit: 20)

        stateManager = StateManager(storage: storage, network: network, newWallet: newWallet)

        let addressSelector: IAddressSelector
        switch coin {
        case .bitcoin: addressSelector = BitcoinAddressSelector(addressConverter: addressConverter)
        case .bitcoinCash: addressSelector = BitcoinCashAddressSelector(addressConverter: addressConverter)
        }

//        initialSyncApi = BtcComApi(network: network, logger: logger)
        let bcoinApiManager = BCoinApi(network: network, logger: logger)

        let blockHashFetcherHelper = BlockHashFetcherHelper()
        let blockHashFetcher = BlockHashFetcher(addressSelector: addressSelector, apiManager: bcoinApiManager, helper: blockHashFetcherHelper)

        blockDiscovery = BlockDiscoveryBatch(network: network, wallet: hdWallet, blockHashFetcher: blockHashFetcher, logger: logger)

        feeRateApiProvider = FeeRateApiProvider()
        ipfsApi = IpfsApi(network: network, apiProvider: feeRateApiProvider, logger: logger)

        reachabilityManager = ReachabilityManager()

        let peerDiscovery = PeerDiscovery()
        peerAddressManager = PeerAddressManager(storage: storage, network: network, peerDiscovery: peerDiscovery, logger: logger)
        peerDiscovery.peerAddressManager = peerAddressManager

        factory = Factory()
        kitStateProvider = KitStateProvider()

        bloomFilterManager = BloomFilterManager(realmFactory: realmFactory, factory: factory)
        peerGroup = PeerGroup(factory: factory, network: network, listener: kitStateProvider, reachabilityManager: reachabilityManager, peerAddressManager: peerAddressManager, bloomFilterManager: bloomFilterManager, logger: logger)

        addressManager = AddressManager.instance(realmFactory: realmFactory, hdWallet: hdWallet, addressConverter: addressConverter)
        initialSyncer = InitialSyncer(storage: storage, listener: kitStateProvider, stateManager: stateManager, blockDiscovery: blockDiscovery, addressManager: addressManager, logger: logger)

        bcoinReachabilityManager = ReachabilityManager(configProvider: feeRateApiProvider)

        feeRateSyncer = FeeRateSyncer(api: ipfsApi, storage: storage)

        inputSigner = InputSigner(hdWallet: hdWallet, network: network)
        scriptBuilder = ScriptBuilder()

        transactionSizeCalculator = TransactionSizeCalculator()
        unspentOutputSelector = UnspentOutputSelector(calculator: transactionSizeCalculator)
        unspentOutputProvider = UnspentOutputProvider(realmFactory: realmFactory, confirmationsThreshold: confirmationsThreshold)

        transactionPublicKeySetter = TransactionPublicKeySetter(realmFactory: realmFactory)
        transactionOutputExtractor = TransactionOutputExtractor(transactionKeySetter: transactionPublicKeySetter)
        transactionOutputAddressExtractor = TransactionOutputAddressExtractor(addressConverter: addressConverter)
        transactionInputExtractor = TransactionInputExtractor(scriptConverter: scriptConverter, addressConverter: addressConverter)
        transactionLinker = TransactionLinker()
        transactionProcessor = TransactionProcessor(outputExtractor: transactionOutputExtractor, inputExtractor: transactionInputExtractor, linker: transactionLinker, outputAddressExtractor: transactionOutputAddressExtractor, addressManager: addressManager)

        transactionSyncer = TransactionSyncer(realmFactory: realmFactory, processor: transactionProcessor, addressManager: addressManager, bloomFilterManager: bloomFilterManager)
        transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, addressManager: addressManager, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        transactionCreator = TransactionCreator(realmFactory: realmFactory, transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, peerGroup: peerGroup)

        dataProvider = DataProvider(realmFactory: realmFactory, storage: storage, addressManager: addressManager, addressConverter: addressConverter, paymentAddressParser: paymentAddressParser, unspentOutputProvider: unspentOutputProvider, transactionCreator: transactionCreator, transactionBuilder: transactionBuilder, network: network)

        blockchain = Blockchain(network: network, factory: factory, listener: dataProvider)
        blockSyncer = BlockSyncer(storage: storage, network: network, factory: factory, listener: kitStateProvider, transactionProcessor: transactionProcessor, blockchain: blockchain, addressManager: addressManager, bloomFilterManager: bloomFilterManager, logger: logger)

        syncManager = SyncManager(reachabilityManager: reachabilityManager, feeRateSyncer: feeRateSyncer, initialSyncer: initialSyncer, peerGroup: peerGroup)

        peerGroup.blockSyncer = blockSyncer
        peerGroup.transactionSyncer = transactionSyncer
        initialSyncer.delegate = syncManager

        kitStateProvider.delegate = self
        transactionProcessor.listener = dataProvider

        dataProvider.delegate = self
    }

}

extension BitcoinKit {

    public func start() throws {
        syncManager.start()
    }

    public func clear() throws {
        syncManager.stop()
        try storage.clear()
    }

}

extension BitcoinKit {

    public var lastBlockInfo: BlockInfo? {
        return dataProvider.lastBlockInfo
    }

    public var balance: Int {
        return dataProvider.balance
    }

    public var syncState: BitcoinKit.KitState {
        return kitStateProvider.syncState
    }

    public func transactions(fromHash: String? = nil, limit: Int? = nil) -> Single<[TransactionInfo]> {
        return dataProvider.transactions(fromHash: fromHash, limit: limit)
    }

    public func send(to address: String, value: Int) throws {
        try dataProvider.send(to: address, value: value)
    }

    public func validate(address: String) throws {
       try dataProvider.validate(address: address)
    }

    public func parse(paymentAddress: String) -> BitcoinPaymentData {
        return dataProvider.parse(paymentAddress: paymentAddress)
    }

    public func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try dataProvider.fee(for: value, toAddress: toAddress, senderPay: senderPay)
    }

    public var receiveAddress: String {
        return dataProvider.receiveAddress
    }

    public var debugInfo: String {
        return dataProvider.debugInfo
    }

}

extension BitcoinKit: IDataProviderDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.transactionsUpdated(bitcoinKit: kit, inserted: inserted, updated: updated)
            }
        }
    }

    func transactionsDeleted(hashes: [String]) {
        delegateQueue.async { [weak self] in
            self?.delegate?.transactionsDeleted(hashes: hashes)
        }
    }

    func balanceUpdated(balance: Int) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.balanceUpdated(bitcoinKit: kit, balance: balance)
            }
        }
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.lastBlockInfoUpdated(bitcoinKit: kit, lastBlockInfo: lastBlockInfo)
            }
        }
    }

}

extension BitcoinKit: IKitStateProviderDelegate {
    func handleKitStateUpdate(state: KitState) {
        delegateQueue.async { [weak self] in
            self?.delegate?.kitStateUpdated(state: state)
        }
    }
}

public protocol BitcoinKitDelegate: class {
    func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo])
    func transactionsDeleted(hashes: [String])
    func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int)
    func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo)
    func kitStateUpdated(state: BitcoinKit.KitState)
}

extension BitcoinKit {

    public enum Coin {
        case bitcoin(network: Network)
        case bitcoinCash(network: Network)

        var rawValue: String {
            switch self {
            case .bitcoin(let network):
                return "btc-\(network)"
            case .bitcoinCash(let network):
                return "bch-\(network)"
            }
        }
    }

    public enum Network {
        case mainNet
        case testNet
        case regTest
    }

    public enum KitState {
        case synced
        case syncing(progress: Double)
        case notSynced
    }

}

extension BitcoinKit.KitState {

    public static func == (lhs: BitcoinKit.KitState, rhs: BitcoinKit.KitState) -> Bool {
        switch (lhs, rhs) {
        case (.synced, .synced), (.notSynced, .notSynced):
            return true
        case (.syncing(progress: let leftProgress), .syncing(progress: let rightProgress)):
            return leftProgress == rightProgress
        default:
            return false
        }
    }

}