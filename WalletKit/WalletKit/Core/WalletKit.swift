import Foundation
import RealmSwift
import RxSwift
import BigInt

public class WalletKit {

    public enum NetworkType {
        case bitcoinMainNet
        case bitcoinTestNet
        case bitcoinRegTest
        case bitcoinCashMainNet
        case bitcoinCashTestNet
    }

    let disposeBag = DisposeBag()

    public weak var delegate: BitcoinKitDelegate?

    private var unspentOutputsNotificationToken: NotificationToken?
    private var transactionsNotificationToken: NotificationToken?
    private var blocksNotificationToken: NotificationToken?

    let difficultyEncoder: DifficultyEncoder
    let blockHelper: BlockHelper
    let validatorFactory: BlockValidatorFactory

    let network: NetworkProtocol

    let realmFactory: RealmFactory

    let hdWallet: HDWallet

    let peerHostManager: PeerHostManager
    let stateManager: StateManager
    let apiManager: ApiManager
    let addressManager: AddressManager

    let peerGroup: PeerGroup
    let factory: Factory

    let initialSyncer: InitialSyncer
    let progressSyncer: ProgressSyncer

    let validatedBlockFactory: ValidatedBlockFactory

    let bech32AddressConverter: Bech32AddressConverter
    let addressConverter: AddressConverter
    let scriptConverter: ScriptConverter
    let transactionProcessor: TransactionProcessor
    let transactionExtractor: TransactionExtractor
    let transactionLinker: TransactionLinker
    let transactionSyncer: TransactionSyncer
    let transactionCreator: TransactionCreator
    let transactionBuilder: TransactionBuilder

    let inputSigner: InputSigner
    let scriptBuilder: ScriptBuilder
    let transactionSizeCalculator: TransactionSizeCalculator
    let unspentOutputSelector: UnspentOutputSelector
    let unspentOutputProvider: UnspentOutputProvider

    let headerSyncer: HeaderSyncer
    let blockSyncer: BlockSyncer

    public init(withWords words: [String], networkType: NetworkType) {
        let wordsHash = words.joined()
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

        hdWallet = HDWallet(seed: Mnemonic.seed(mnemonic: words), network: network)

        stateManager = StateManager(realmFactory: realmFactory)
        apiManager = ApiManager(apiUrl: "http://ipfs.grouvi.org/ipns/QmVefrf2xrWzGzPpERF6fRHeUTh9uVSyfHHh4cWgUBnXpq/io-hs/data/blockstore")
        peerHostManager = PeerHostManager(network: network, realmFactory: realmFactory)

        let realm = realmFactory.realm
        let pubKeys = realm.objects(PublicKey.self)
        let filters = Array(pubKeys.map { $0.keyHash }) + Array(pubKeys.map { $0.raw! })

        peerGroup = PeerGroup(network: network, peerHostManager: peerHostManager, bloomFilters: filters)
        factory = Factory()

        addressConverter = AddressConverter(network: network, bech32AddressConverter: bech32AddressConverter)

        addressManager = AddressManager(realmFactory: realmFactory, hdWallet: hdWallet, peerGroup: peerGroup, addressConverter: addressConverter)
        initialSyncer = InitialSyncer(realmFactory: realmFactory, hdWallet: hdWallet, stateManager: stateManager, apiManager: apiManager, addressManager: addressManager, addressConverter: addressConverter, factory: factory, peerGroup: peerGroup, network: network)
        progressSyncer = ProgressSyncer(realmFactory: realmFactory)

        validatedBlockFactory = ValidatedBlockFactory(realmFactory: realmFactory, factory: factory, network: network)

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

        headerSyncer = HeaderSyncer(realmFactory: realmFactory, validateBlockFactory: validatedBlockFactory, network: network)
        blockSyncer = BlockSyncer(realmFactory: realmFactory, validateBlockFactory: validatedBlockFactory, processor: transactionProcessor, progressSyncer: progressSyncer)

        peerGroup.headersSyncer = headerSyncer
        peerGroup.blockSyncer = blockSyncer
        peerGroup.transactionSyncer = transactionSyncer

        unspentOutputsNotificationToken = unspentOutputRealmResults.observe { [weak self] changeset in
            self?.handleUnspentOutputs(changeset: changeset)
        }

        transactionsNotificationToken = transactionRealmResults.observe { [weak self] changeset in
            self?.handleTransactions(changeset: changeset)
        }

        blocksNotificationToken = blockRealmResults.observe { [weak self] changeset in
            self?.handleBlocks(changeset: changeset)
        }

        progressSyncer.subject.subscribeInBackground(disposeBag: disposeBag, onNext: { [weak self] progress in
            self?.handleProgressUpdate(progress: progress)
        })

        progressSyncer.enqueueRun()
    }

    deinit {
        unspentOutputsNotificationToken?.invalidate()
        transactionsNotificationToken?.invalidate()
        blocksNotificationToken?.invalidate()
    }

    public func showRealmInfo() {
        let realm = realmFactory.realm

        let blocks = realm.objects(Block.self).sorted(byKeyPath: "height")
        let syncedBlocks = blocks.filter("synced = %@", true)
        let pubKeys = realm.objects(PublicKey.self)

        for pubKey in pubKeys {
            print("\(pubKey.index) --- \(pubKey.external) --- \(pubKey.keyHash.hex) --- \(addressConverter.convertToLegacy(keyHash: pubKey.keyHash, version: network.pubKeyHash, addressType: .pubKeyHash).stringValue) --- \(try! addressConverter.convert(keyHash: pubKey.keyHash, type: .p2pkh).stringValue)")
        }
        print("PUBLIC KEYS COUNT: \(pubKeys.count)")

        print("BLOCK COUNT: \(blocks.count) --- \(syncedBlocks.count) synced")
        if let block = syncedBlocks.first {
            print("First Synced Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }
        if let block = syncedBlocks.last {
            print("Last Synced Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }
    }

    public func start() throws {
        try initialSyncer.sync()
    }

    public func clear() throws {
        let realm = realmFactory.realm

        try realm.write {
            realm.deleteAll()
        }
    }

    public var transactions: [TransactionInfo] {
        return transactionRealmResults.map { transactionInfo(fromTransaction: $0) }
    }

    public var lastBlockInfo: BlockInfo? {
        return blockRealmResults.last.map { blockInfo(fromBlock: $0) }
    }

    public var balance: Int {
        var balance = 0

        for output in unspentOutputRealmResults {
            balance += output.value
        }

        return balance
    }

    public func send(to address: String, value: Int) throws {
        try transactionCreator.create(to: address, value: value)
    }

    public func validate(address: String) throws {
       _ = try addressConverter.convert(address: address)
    }

    public func fee(for value: Int, toAddress: String? = nil, senderPay: Bool) throws -> Int {
        return try transactionBuilder.fee(for: value, feeRate: transactionCreator.feeRate, senderPay: true, address: toAddress)
    }

    public var receiveAddress: String {
        return (try? addressManager.receiveAddress()) ?? ""
    }

    public var progress: Double {
        return progressSyncer.progress
    }

    private func handleTransactions(changeset: RealmCollectionChange<Results<Transaction>>) {
        if case let .update(collection, deletions, insertions, modifications) = changeset {
            delegate?.transactionsUpdated(
                    walletKit: self,
                    inserted: insertions.map { collection[$0] }.map { transactionInfo(fromTransaction: $0) },
                    updated: modifications.map { collection[$0] }.map { transactionInfo(fromTransaction: $0) },
                    deleted: deletions
            )
        }
    }

    private func handleBlocks(changeset: RealmCollectionChange<Results<Block>>) {
        if case let .update(collection, deletions, insertions, _) = changeset, let block = collection.last, (!deletions.isEmpty || !insertions.isEmpty) {
            delegate?.lastBlockInfoUpdated(walletKit: self, lastBlockInfo: blockInfo(fromBlock: block))
        }
    }

    private func handleUnspentOutputs(changeset: RealmCollectionChange<Results<TransactionOutput>>) {
        if case .update = changeset {
            delegate?.balanceUpdated(walletKit: self, balance: balance)
        }
    }

    private func handleProgressUpdate(progress: Double) {
        delegate?.progressUpdated(walletKit: self, progress: progress)
    }

    private var unspentOutputRealmResults: Results<TransactionOutput> {
        return realmFactory.realm.objects(TransactionOutput.self)
                .filter("publicKey != nil")
                .filter("scriptType = %@ OR scriptType = %@", ScriptType.p2pkh.rawValue, ScriptType.p2pk.rawValue)
                .filter("inputs.@count = %@", 0)
    }

    private var transactionRealmResults: Results<Transaction> {
        return realmFactory.realm.objects(Transaction.self).filter("isMine = %@", true).sorted(byKeyPath: "block.height", ascending: false)
    }

    private var blockRealmResults: Results<Block> {
        return realmFactory.realm.objects(Block.self).filter("synced = %@", true).sorted(byKeyPath: "height")
    }

    private func transactionInfo(fromTransaction transaction: Transaction) -> TransactionInfo {
        var totalMineInput: Int = 0
        var totalMineOutput: Int = 0
        var fromAddresses = [TransactionAddress]()
        var toAddresses = [TransactionAddress]()

        for input in transaction.inputs {
            if let previousOutput = input.previousOutput {
                if previousOutput.publicKey != nil {
                    totalMineInput += previousOutput.value
                }
            }

            let mine = input.previousOutput?.publicKey != nil

            if let address = input.address {
                fromAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        for output in transaction.outputs {
            var mine = false

            if output.publicKey != nil {
                totalMineOutput += output.value
                mine = true
            }

            if let address = output.address {
                toAddresses.append(TransactionAddress(address: address, mine: mine))
            }
        }

        let amount = totalMineOutput - totalMineInput

        return TransactionInfo(
                transactionHash: transaction.reversedHashHex,
                from: fromAddresses,
                to: toAddresses,
                amount: amount,
                blockHeight: transaction.block?.height,
                timestamp: transaction.block?.header?.timestamp
        )
    }

    private func blockInfo(fromBlock block: Block) -> BlockInfo {
        return BlockInfo(
                headerHash: block.reversedHeaderHashHex,
                height: block.height,
                timestamp: block.header?.timestamp
        )
    }

}

public protocol BitcoinKitDelegate: class {
    func transactionsUpdated(walletKit: WalletKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int])
    func balanceUpdated(walletKit: WalletKit, balance: Int)
    func lastBlockInfoUpdated(walletKit: WalletKit, lastBlockInfo: BlockInfo)
    func progressUpdated(walletKit: WalletKit, progress: Double)
}
