import Foundation
import RealmSwift
import RxSwift

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
    let difficultyCalculator: DifficultyCalculator

    let network: NetworkProtocol
    let blockValidator: BlockValidator

    let realmFactory: RealmFactory
    let logger: Logger

    let hdWallet: HDWallet

    let stateManager: StateManager
    let apiManager: ApiManager
    let addressManager: AddressManager

    let peerGroup: PeerGroup
    let syncer: Syncer
    let factory: Factory

    let initialSyncer: InitialSyncer
    let progressSyncer: ProgressSyncer

    let blockSyncer: BlockSyncer

    let validatedBlockFactory: ValidatedBlockFactory

    let headerSyncer: HeaderSyncer
    let headerHandler: HeaderHandler

    let addressConverter: AddressConverter
    let scriptConverter: ScriptConverter
    let transactionProcessor: TransactionProcessor
    let transactionExtractor: TransactionExtractor
    let transactionLinker: TransactionLinker
    let transactionHandler: TransactionHandler
    let transactionSender: TransactionSender
    let transactionCreator: TransactionCreator
    let transactionBuilder: TransactionBuilder

    let inputSigner: InputSigner
    let scriptBuilder: ScriptBuilder
    let transactionSizeCalculator: TransactionSizeCalculator
    let unspentOutputSelector: UnspentOutputSelector
    let unspentOutputProvider: UnspentOutputProvider

    public init(withWords words: [String], networkType: NetworkType) {
        let wordsHash = words.joined()
        let realmFileName = "\(wordsHash)-\(networkType).realm"

        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let realmConfiguration = Realm.Configuration(fileURL: documentsUrl?.appendingPathComponent(realmFileName))

        difficultyEncoder = DifficultyEncoder()
        difficultyCalculator = DifficultyCalculator(difficultyEncoder: difficultyEncoder)

        switch networkType {
        case .bitcoinMainNet:
            network = BitcoinMainNet()
            blockValidator = BlockValidator(calculator: difficultyCalculator)
        case .bitcoinTestNet:
            network = BitcoinTestNet()
            blockValidator = TestNetBlockValidator(calculator: difficultyCalculator)
        case .bitcoinRegTest:
            network = BitcoinRegTest()
            blockValidator = RegTestBlockValidator(calculator: difficultyCalculator)
        case .bitcoinCashMainNet:
            network = BitcoinCashMainNet()
            blockValidator = BlockValidator(calculator: difficultyCalculator)
        case .bitcoinCashTestNet:
            network = BitcoinCashTestNet()
            blockValidator = TestNetBlockValidator(calculator: difficultyCalculator)
        }

        realmFactory = RealmFactory(configuration: realmConfiguration)
        logger = Logger()

        hdWallet = HDWallet(seed: Mnemonic.seed(mnemonic: words), network: network)

        stateManager = StateManager(realmFactory: realmFactory)
        apiManager = ApiManager(apiUrl: "http://ipfs.grouvi.org/ipns/QmVefrf2xrWzGzPpERF6fRHeUTh9uVSyfHHh4cWgUBnXpq/io-hs/data/blockstore")

        peerGroup = PeerGroup(realmFactory: realmFactory, network: network)
        syncer = Syncer(logger: logger, realmFactory: realmFactory)
        factory = Factory()

        initialSyncer = InitialSyncer(realmFactory: realmFactory, hdWallet: hdWallet, stateManager: stateManager, apiManager: apiManager, factory: factory, peerGroup: peerGroup, network: network)
        addressManager = AddressManager(realmFactory: realmFactory, hdWallet: hdWallet, peerGroup: peerGroup)
        progressSyncer = ProgressSyncer(realmFactory: realmFactory)
        blockSyncer = BlockSyncer(realmFactory: realmFactory, peerGroup: peerGroup)

        validatedBlockFactory = ValidatedBlockFactory(realmFactory: realmFactory, factory: factory, validator: blockValidator, network: network)

        headerSyncer = HeaderSyncer(realmFactory: realmFactory, peerGroup: peerGroup, network: network)
        headerHandler = HeaderHandler(realmFactory: realmFactory, validateBlockFactory: validatedBlockFactory, blockSyncer: blockSyncer)

        inputSigner = InputSigner(hdWallet: hdWallet)
        scriptBuilder = ScriptBuilder()

        transactionSizeCalculator = TransactionSizeCalculator()
        unspentOutputSelector = UnspentOutputSelector(calculator: transactionSizeCalculator)
        unspentOutputProvider = UnspentOutputProvider(realmFactory: realmFactory)

        addressConverter = AddressConverter(network: network)
        scriptConverter = ScriptConverter()
        transactionExtractor = TransactionExtractor(scriptConverter: scriptConverter, addressConverter: addressConverter)
        transactionLinker = TransactionLinker()
        transactionProcessor = TransactionProcessor(realmFactory: realmFactory, extractor: transactionExtractor, linker: transactionLinker, addressManager: addressManager, logger: logger)
        transactionHandler = TransactionHandler(realmFactory: realmFactory, processor: transactionProcessor, progressSyncer: progressSyncer, validateBlockFactory: validatedBlockFactory)
        transactionSender = TransactionSender(realmFactory: realmFactory, peerGroup: peerGroup)
        transactionBuilder = TransactionBuilder(unspentOutputSelector: unspentOutputSelector, unspentOutputProvider: unspentOutputProvider, transactionSizeCalculator: transactionSizeCalculator, addressConverter: addressConverter, inputSigner: inputSigner, scriptBuilder: scriptBuilder, factory: factory)
        transactionCreator = TransactionCreator(realmFactory: realmFactory, transactionBuilder: transactionBuilder, transactionProcessor: transactionProcessor, transactionSender: transactionSender, addressManager: addressManager)

        peerGroup.delegate = syncer

        syncer.headerSyncer = headerSyncer
        syncer.headerHandler = headerHandler
        syncer.transactionHandler = transactionHandler
        syncer.transactionSender = transactionSender
        syncer.blockSyncer = blockSyncer

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

        let blockCount = realm.objects(Block.self).count
        let syncedBlockCount = realm.objects(Block.self).filter("synced = %@", true).count
        let pubKeysCount = realm.objects(PublicKey.self).count

        print("BLOCK COUNT: \(blockCount) --- \(syncedBlockCount) synced")
        if let block = realm.objects(Block.self).first {
            print("First Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }
        if let block = realm.objects(Block.self).last {
            print("Last Block: \(block.height) --- \(block.reversedHeaderHashHex)")
        }

        print("PUBLIC KEYS COUNT: \(pubKeysCount)")
        for pubKey in realm.objects(PublicKey.self) {
            print("\(pubKey.index) --- \(pubKey.external) --- \(pubKey.address)")
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

    public var lastBlockHeight: Int {
        return blockRealmResults.last?.height ?? 0
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
                    deleted: deletions.map { collection[$0] }.map { transactionInfo(fromTransaction: $0) }
            )
        }
    }

    private func handleBlocks(changeset: RealmCollectionChange<Results<Block>>) {
        if case let .update(collection, deletions, insertions, _) = changeset, let height = collection.last?.height, (!deletions.isEmpty || !insertions.isEmpty) {
            delegate?.lastBlockHeightUpdated(walletKit: self, lastBlockHeight: height)
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
        return realmFactory.realm.objects(Block.self).sorted(byKeyPath: "height")
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

}

public protocol BitcoinKitDelegate: class {
    func transactionsUpdated(walletKit: WalletKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [TransactionInfo])
    func balanceUpdated(walletKit: WalletKit, balance: Int)
    func lastBlockHeightUpdated(walletKit: WalletKit, lastBlockHeight: Int)
    func progressUpdated(walletKit: WalletKit, progress: Double)
}
