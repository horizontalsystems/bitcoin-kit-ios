import Foundation
import HSHDWalletKit
import RealmSwift
import BigInt
import HSCryptoKit

public class BitcoinKit {

    public enum NetworkType {
        case bitcoinMainNet
        case bitcoinTestNet
        case bitcoinRegTest
        case bitcoinCashMainNet
        case bitcoinCashTestNet
    }

    public weak var delegate: BitcoinKitDelegate?

    private var unspentOutputsNotificationToken: NotificationToken?
    private var transactionsNotificationToken: NotificationToken?
    private var blocksNotificationToken: NotificationToken?

    private let difficultyEncoder: IDifficultyEncoder
    private let blockHelper: IBlockHelper
    private let validatorFactory: IBlockValidatorFactory

    private let network: INetwork

    private let realmFactory: IRealmFactory

    private let hdWallet: IHDWallet

    private let peerHostManager: IPeerHostManager
    private let stateManager: IStateManager
    private let apiManager: IApiManager
    private let addressManager: IAddressManager
    private let bloomFilterManager: IBloomFilterManager

    private var peerGroup: IPeerGroup
    private let factory: IFactory

    private let initialSyncer: IInitialSyncer
    private let progressSyncer: IProgressSyncer

    private let bech32AddressConverter: IBech32AddressConverter
    private let addressConverter: IAddressConverter
    private let scriptConverter: IScriptConverter
    private let transactionProcessor: ITransactionProcessor
    private let transactionExtractor: ITransactionExtractor
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

    private var dataProvider: IDataProvider

    public init(withWords words: [String], networkType: NetworkType) {
        let wordsHash = words.joined().data(using: .utf8).map { CryptoKit.sha256($0).hex } ?? words[0]

        let realmFileName = "\(wordsHash)-\(networkType).realm"

        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let realmConfiguration = Realm.Configuration(fileURL: documentsUrl?.appendingPathComponent(realmFileName))

        difficultyEncoder = DifficultyEncoder()
        blockHelper = BlockHelper()
        validatorFactory = BlockValidatorFactory(difficultyEncoder: difficultyEncoder, blockHelper: blockHelper)

        switch networkType {
        case .bitcoinMainNet:
            network = BitcoinMainNet(validatorFactory: validatorFactory)
            bech32AddressConverter = SegWitBech32AddressConverter()
        case .bitcoinTestNet:
            network = BitcoinTestNet(validatorFactory: validatorFactory)
            bech32AddressConverter = SegWitBech32AddressConverter()
        case .bitcoinRegTest:
            network = BitcoinRegTest(validatorFactory: validatorFactory)
            bech32AddressConverter = SegWitBech32AddressConverter()
        case .bitcoinCashMainNet:
            network = BitcoinCashMainNet(validatorFactory: validatorFactory, blockHelper: blockHelper)
            bech32AddressConverter = CashBech32AddressConverter()
        case .bitcoinCashTestNet:
            network = BitcoinCashTestNet(validatorFactory: validatorFactory)
            bech32AddressConverter = CashBech32AddressConverter()
        }

        realmFactory = RealmFactory(configuration: realmConfiguration)

        hdWallet = HDWallet(seed: Mnemonic.seed(mnemonic: words), coinType: network.coinType, xPrivKey: network.xPrivKey, xPubKey: network.xPubKey)

        stateManager = StateManager(realmFactory: realmFactory)
        apiManager = ApiManager(apiUrl: "http://ipfs.grouvi.org/ipns/QmVefrf2xrWzGzPpERF6fRHeUTh9uVSyfHHh4cWgUBnXpq/io-hs/data/blockstore")
        peerHostManager = PeerHostManager(network: network, realmFactory: realmFactory)

        factory = Factory()
        bloomFilterManager = BloomFilterManager(realmFactory: realmFactory)
        peerGroup = PeerGroup(factory: factory, network: network, peerHostManager: peerHostManager, bloomFilterManager: bloomFilterManager)

        addressConverter = AddressConverter(network: network, bech32AddressConverter: bech32AddressConverter)

        addressManager = AddressManager(realmFactory: realmFactory, hdWallet: hdWallet, bloomFilterManager: bloomFilterManager, addressConverter: addressConverter)
        initialSyncer = InitialSyncer(realmFactory: realmFactory, hdWallet: hdWallet, stateManager: stateManager, apiManager: apiManager, addressManager: addressManager, addressConverter: addressConverter, factory: factory, peerGroup: peerGroup, network: network)
        progressSyncer = ProgressSyncer(realmFactory: realmFactory)

        inputSigner = InputSigner(hdWallet: hdWallet)
        scriptBuilder = ScriptBuilder()

        transactionSizeCalculator = TransactionSizeCalculator()
        unspentOutputSelector = UnspentOutputSelector(calculator: transactionSizeCalculator)
        unspentOutputProvider = UnspentOutputProvider(realmFactory: realmFactory)

        scriptConverter = ScriptConverter()
        transactionExtractor = TransactionExtractor(scriptConverter: scriptConverter, addressConverter: addressConverter)
        transactionLinker = TransactionLinker()
        transactionProcessor = TransactionProcessor(realmFactory: realmFactory, extractor: transactionExtractor, linker: transactionLinker, addressManager: addressManager)
        transactionSyncer = TransactionSyncer(realmFactory: realmFactory, processor: transactionProcessor)
        transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, transactionSizeCalculator: transactionSizeCalculator, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        transactionCreator = TransactionCreator(realmFactory: realmFactory, transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, peerGroup: peerGroup, addressManager: addressManager)
        blockchain = Blockchain(network: network, factory: factory)

        blockSyncer = BlockSyncer(realmFactory: realmFactory, network: network, progressSyncer: progressSyncer, transactionProcessor: transactionProcessor, blockchain: blockchain, addressManager: addressManager)

        peerGroup.blockSyncer = blockSyncer
        peerGroup.transactionSyncer = transactionSyncer

        dataProvider = DataProvider(realmFactory: realmFactory, progressSyncer: progressSyncer, addressManager: addressManager, addressConverter: addressConverter, transactionCreator: transactionCreator, transactionBuilder: transactionBuilder, network: network)
        dataProvider.delegate = self
    }

}

extension BitcoinKit {

    public func start() throws {
        progressSyncer.enqueueRun()
        bloomFilterManager.regenerateBloomFilter()
        try initialSyncer.sync()
    }

    public func clear() throws {
        let realm = realmFactory.realm

        try realm.write {
            realm.deleteAll()
        }
    }

}

extension BitcoinKit {

    public var transactions: [TransactionInfo] {
        return dataProvider.transactions
    }

    public var lastBlockInfo: BlockInfo? {
        return dataProvider.lastBlockInfo
    }

    public var balance: Int {
        return dataProvider.balance
    }

    public func send(to address: String, value: Int) throws {
        try dataProvider.send(to: address, value: value)
    }

    public func validate(address: String) throws {
       try dataProvider.validate(address: address)
    }

    public func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try dataProvider.fee(for: value, toAddress: toAddress, senderPay: senderPay)
    }

    public var receiveAddress: String {
        return dataProvider.receiveAddress
    }

    public var progress: Double {
        return dataProvider.progress
    }

    public var debugInfo: String {
        return dataProvider.debugInfo
    }

}

extension BitcoinKit: DataProviderDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int]) {
        delegate?.transactionsUpdated(bitcoinKit: self, inserted: inserted, updated: updated, deleted: deleted)
    }

    func balanceUpdated(balance: Int) {
        delegate?.balanceUpdated(bitcoinKit: self, balance: balance)
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        delegate?.lastBlockInfoUpdated(bitcoinKit: self, lastBlockInfo: lastBlockInfo)
    }

    func progressUpdated(progress: Double) {
        delegate?.progressUpdated(bitcoinKit: self, progress: progress)
    }

}

public protocol BitcoinKitDelegate: class {
    func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int])
    func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int)
    func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo)
    func progressUpdated(bitcoinKit: BitcoinKit, progress: Double)
}
