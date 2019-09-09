import BitcoinCore
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class DashKit: AbstractKit {
    private static let name = "DashKit"
    private static let heightInterval = 24                                      // Blocks count in window for calculating difficulty
    private static let targetSpacing = 150                                      // Time to mining one block ( 2.5 min. Dash )
    private static let maxTargetBits = 0x1e0fffff                               // Initially and max. target difficulty for blocks ( Dash )

    public enum NetworkType: String, CaseIterable { case mainNet, testNet }

    weak public var delegate: DashKitDelegate?

    private let storage: IDashStorage

    private var masternodeSyncer: MasternodeListSyncer?
    private var instantSend: InstantSend?
    private let dashTransactionInfoConverter: ITransactionInfoConverter

    public init(withWords words: [String], walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        var initialSyncApiUrl: String

        switch networkType {
        case .mainNet:
            network = MainNet()
            initialSyncApiUrl = "https://dash.horizontalsystems.xyz/apg"
        case .testNet:
            network = TestNet()
            initialSyncApiUrl = "http://dash-testnet.horizontalsystems.xyz/apg"
        }
        let initialSyncApi = InsightApi(url: initialSyncApiUrl)

        let logger = Logger(network: network, minLogLevel: minLogLevel)

        let databaseFilePath = try DirectoryHelper.directoryURL(for: DashKit.name).appendingPathComponent(DashKit.databaseFileName(walletId: walletId, networkType: networkType)).path
        let storage = DashGrdbStorage(databaseFilePath: databaseFilePath)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "dash", removeScheme: true)

        let singleHasher = SingleHasher()   // Use single sha256 for hash
        let doubleShaHasher = DoubleShaHasher()     // Use doubleSha256 for hash
        let x11Hasher = X11Hasher()         // Use for block header hash

        let instantSendFactory = InstantSendFactory()
        let instantTransactionState = InstantTransactionState()
        let instantTransactionManager = InstantTransactionManager(storage: storage, instantSendFactory: instantSendFactory, instantTransactionState: instantTransactionState)

        dashTransactionInfoConverter = DashTransactionInfoConverter(baseTransactionInfoConverter: BaseTransactionInfoConverter(), instantTransactionManager: instantTransactionManager)

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
                .set(network: network)
                .set(words: words)
                .set(initialSyncApi: initialSyncApi)
                .set(paymentAddressParser: paymentAddressParser)
                .set(walletId: walletId)
                .set(confirmationsThreshold: confirmationsThreshold)
                .set(peerSize: 10)
                .set(storage: storage)
                .set(syncMode: syncMode)
                .set(blockHeaderHasher: x11Hasher)
                .set(transactionInfoConverter: dashTransactionInfoConverter)
                .build()
        super.init(bitcoinCore: bitcoinCore, network: network)
        bitcoinCore.delegate = self

        // extending BitcoinCore

        let masternodeParser = MasternodeParser(hasher: singleHasher)
        let quorumParser = QuorumParser(hasher: doubleShaHasher)

        bitcoinCore.add(messageParser: TransactionLockMessageParser())
                .add(messageParser: TransactionLockVoteMessageParser())
                .add(messageParser: MasternodeListDiffMessageParser(masternodeParser: masternodeParser, quorumParser: quorumParser))
                .add(messageParser: ISLockParser(hasher: doubleShaHasher))

        bitcoinCore.add(messageSerializer: GetMasternodeListDiffMessageSerializer())

        let blockHelper = BlockValidatorHelper(storage: storage)
        let difficultyEncoder = DifficultyEncoder()

        let targetTimespan = DashKit.heightInterval * DashKit.targetSpacing                 // Time to mining all 24 blocks in circle
        switch networkType {
        case .mainNet:
            bitcoinCore.add(blockValidator: DarkGravityWaveValidator(encoder: difficultyEncoder, blockHelper: blockHelper, heightInterval: DashKit.heightInterval , targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits, firstCheckpointHeight: network.lastCheckpointBlock.height, powDGWHeight: 68589))
        case .testNet:
            bitcoinCore.add(blockValidator: DarkGravityWaveTestNetValidator(difficultyEncoder: difficultyEncoder, targetSpacing: DashKit.targetSpacing, targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits, powDGWHeight: 4002))
            bitcoinCore.add(blockValidator: DarkGravityWaveValidator(encoder: difficultyEncoder, blockHelper: blockHelper, heightInterval: DashKit.heightInterval, targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits, firstCheckpointHeight: network.lastCheckpointBlock.height, powDGWHeight: 4002))
        }

        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)

        let masternodeSerializer = MasternodeSerializer()
        let coinbaseTransactionSerializer = CoinbaseTransactionSerializer()
        let masternodeCbTxHasher = MasternodeCbTxHasher(coinbaseTransactionSerializer: coinbaseTransactionSerializer, hasher: doubleShaHasher)

        let masternodeMerkleRootCreator = MerkleRootCreator(hasher: doubleShaHasher)
        let quorumMerkleRootCreator = MerkleRootCreator(hasher: doubleShaHasher)

        let masternodeListMerkleRootCalculator = MasternodeListMerkleRootCalculator(masternodeSerializer: masternodeSerializer, masternodeHasher: doubleShaHasher, masternodeMerkleRootCreator: masternodeMerkleRootCreator)
        let quorumListMerkleRootCalculator = QuorumListMerkleRootCalculator(merkleRootCreator: quorumMerkleRootCreator, quorumHasher: doubleShaHasher)
        let quorumListManager = QuorumListManager(storage: storage, hasher: doubleShaHasher, quorumListMerkleRootCalculator: quorumListMerkleRootCalculator, merkleBranch: merkleBranch)
        let masternodeListManager = MasternodeListManager(storage: storage, quorumListManager: quorumListManager, masternodeListMerkleRootCalculator: masternodeListMerkleRootCalculator, masternodeCbTxHasher: masternodeCbTxHasher, merkleBranch: merkleBranch)
        let masternodeSyncer = MasternodeListSyncer(bitcoinCore: bitcoinCore, initialBlockDownload: bitcoinCore.initialBlockDownload, peerTaskFactory: PeerTaskFactory(), masternodeListManager: masternodeListManager)

        bitcoinCore.add(peerTaskHandler: masternodeSyncer)

        masternodeSyncer.subscribeTo(observable: bitcoinCore.initialBlockDownload.observable)
        masternodeSyncer.subscribeTo(observable: bitcoinCore.peerGroup.observable)

        self.masternodeSyncer = masternodeSyncer

        let calculator = TransactionSizeCalculator()
        let confirmedUnspentOutputProvider = ConfirmedUnspentOutputProvider(storage: storage, confirmationsThreshold: confirmationsThreshold)
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelector(calculator: calculator, provider: confirmedUnspentOutputProvider))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelectorSingleNoChange(calculator: calculator, provider: confirmedUnspentOutputProvider))
// --------------------------------------
        let transactionLockVoteValidator = TransactionLockVoteValidator(storage: storage, hasher: singleHasher)
        let instantSendLockValidator = InstantSendLockValidator(quorumListManager: quorumListManager, hasher: doubleShaHasher)

        let instantTransactionSyncer = InstantTransactionSyncer(transactionSyncer: bitcoinCore.transactionSyncer)
        let lockVoteManager = TransactionLockVoteManager(transactionLockVoteValidator: transactionLockVoteValidator)
        let instantSendLockManager = InstantSendLockManager(instantSendLockValidator: instantSendLockValidator)

        let instantSendLockHandler = InstantSendLockHandler(instantTransactionManager: instantTransactionManager, instantSendLockManager: instantSendLockManager, logger: logger)
        instantSendLockHandler.delegate = self
        let transactionLockVoteHandler = TransactionLockVoteHandler(instantTransactionManager: instantTransactionManager, lockVoteManager: lockVoteManager, logger: logger)
        transactionLockVoteHandler.delegate = self

        let instantSend = InstantSend(transactionSyncer: instantTransactionSyncer, transactionLockVoteHandler: transactionLockVoteHandler, instantSendLockHandler: instantSendLockHandler, logger: logger)
        self.instantSend = instantSend

        bitcoinCore.add(peerTaskHandler: instantSend)
        bitcoinCore.add(inventoryItemsHandler: instantSend)
// --------------------------------------
        bitcoinCore.add(restoreKeyConverterForBip: .bip44)
    }

    private func cast(transactionInfos:[TransactionInfo]) -> [DashTransactionInfo] {
        return transactionInfos.compactMap { $0 as? DashTransactionInfo }
    }

    public override func send(to address: String, value: Int, feeRate: Int) throws -> FullTransaction {
        return try super.send(to: address, value: value, feeRate: feeRate)
    }

    public func transactions(fromHash: String?, limit: Int?) -> Single<[DashTransactionInfo]> {
        return super.transactions(fromHash: fromHash, limit: limit).map { self.cast(transactionInfos: $0) }
    }

}

extension DashKit: BitcoinCoreDelegate {

    public func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        // check for all new transactions if it's has instant lock
        inserted.compactMap { Data(hex : $0.transactionHash) }.forEach { instantSend?.handle(insertedTxHash: $0) }

        delegate?.transactionsUpdated(inserted: cast(transactionInfos: inserted), updated: cast(transactionInfos: updated))
    }

    public func transactionsDeleted(hashes: [String]) {
        delegate?.transactionsDeleted(hashes: hashes)
    }

    public func balanceUpdated(balance: Int) {
        delegate?.balanceUpdated(balance: balance)
    }

    public func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        delegate?.lastBlockInfoUpdated(lastBlockInfo: lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        delegate?.kitStateUpdated(state: state)
    }

}

extension DashKit: IInstantTransactionDelegate {

    public func onUpdateInstant(transactionHash: Data) {
        guard let transaction = storage.fullTransactionInfo(byHash: transactionHash) else {
            return
        }
        let transactionInfo = dashTransactionInfoConverter.transactionInfo(fromTransaction: transaction)
        bitcoinCore.delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.transactionsUpdated(inserted: [], updated: kit.cast(transactionInfos: [transactionInfo]))
            }
        }
    }

}

extension DashKit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        var excludedFileNames = [String]()

        for walletId in walletIdsToExclude {
            for type in NetworkType.allCases {
                excludedFileNames.append(databaseFileName(walletId: walletId, networkType: type))
            }
        }

        try DirectoryHelper.removeAll(inDirectory: DashKit.name, except: excludedFileNames)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType) -> String {
        return "\(walletId)-\(networkType.rawValue)"
    }

}
