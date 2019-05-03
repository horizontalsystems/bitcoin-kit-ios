import BitcoinCore
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class DashKit: AbstractKit {
    private static let heightInterval = 24                                      // Blocks count in window for calculating difficulty
    private static let targetSpacing = 150                                      // Time to mining one block ( 2.5 min. Dash )
    private static let maxTargetBits = 0x1e0fffff                               // Initially and max. target difficulty for blocks ( Dash )

    public enum NetworkType { case mainNet, testNet }

    private let storage: IDashStorage

    private var masternodeSyncer: MasternodeListSyncer?

    public init(withWords words: [String], walletId: String, newWallet: Bool = false, networkType: NetworkType = .mainNet, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        switch networkType {
            case .mainNet: network = MainNet()
            case .testNet: network = TestNet()
        }

        let databaseFileName = "\(walletId)-dash-\(networkType)"

        let storage = DashGrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "dash", removeScheme: true)
        let addressSelector = BitcoinAddressSelector()

        let singleHasher = SingleHasher()   // Use single sha256 for hash
        let doubleShaHasher = DoubleShaHasher()     // Use doubleSha256 for hash
        let x11Hasher = X11Hasher()         // Use for block header hash

        let transactionSizeCalculator = TransactionSizeCalculator()
        let unspentOutputSelector = DashUnspentOutputSelector(calculator: transactionSizeCalculator)
        let dashTransactionInfoConverter = DashTransactionInfoConverter(baseTransactionInfoConverter: BaseTransactionInfoConverter())

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
                .set(network: network)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(walletId: walletId)
                .set(peerSize: 4)
                .set(storage: storage)
                .set(newWallet: newWallet)
                .set(blockHeaderHasher: x11Hasher)
                .set(unspentOutputSelector: unspentOutputSelector)
                .set(transactionInfoConverter: dashTransactionInfoConverter)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore

        let masternodeParser = MasternodeParser(hasher: singleHasher)

        bitcoinCore.add(messageParser: TransactionLockMessageParser())
                .add(messageParser: TransactionLockVoteMessageParser())
                .add(messageParser: MasternodeListDiffMessageParser(masternodeParser: masternodeParser))

        bitcoinCore.add(messageSerializer: GetMasternodeListDiffMessageSerializer())

        let blockHelper = BlockValidatorHelper(storage: storage)
        let difficultyEncoder = DifficultyEncoder()

        let targetTimespan = DashKit.heightInterval * DashKit.targetSpacing                 // Time to mining all 24 blocks in circle
        switch networkType {
        case .mainNet:
            bitcoinCore.add(blockValidator: DarkGravityWaveValidator(encoder: difficultyEncoder, blockHelper: blockHelper, heightInterval: DashKit.heightInterval , targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits, firstCheckpointHeight: network.checkpointBlock.height))
        case .testNet:
            bitcoinCore.add(blockValidator: DarkGravityWaveTestNetValidator(difficultyEncoder: difficultyEncoder, targetSpacing: DashKit.targetSpacing, targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits))
            bitcoinCore.add(blockValidator: DarkGravityWaveValidator(encoder: difficultyEncoder, blockHelper: blockHelper, heightInterval: DashKit.heightInterval, targetTimeSpan: targetTimespan, maxTargetBits: DashKit.maxTargetBits, firstCheckpointHeight: network.checkpointBlock.height))
        }

        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)

        let masternodeSerializer = MasternodeSerializer()
        let coinbaseTransactionSerializer = CoinbaseTransactionSerializer()
        let masternodeCbTxHasher = MasternodeCbTxHasher(coinbaseTransactionSerializer: coinbaseTransactionSerializer, hasher: doubleShaHasher)
        let masternodeMerkleRootCreator = MerkleRootCreator(hasher: doubleShaHasher)

        let masternodeListMerkleRootCalculator = MasternodeListMerkleRootCalculator(masternodeSerializer: masternodeSerializer, masternodeHasher: doubleShaHasher, masternodeMerkleRootCreator: masternodeMerkleRootCreator)
        let masternodeListManager = MasternodeListManager(storage: storage, masternodeListMerkleRootCalculator: masternodeListMerkleRootCalculator, masternodeCbTxHasher: masternodeCbTxHasher, merkleBranch: merkleBranch)
        let masternodeSyncer = MasternodeListSyncer(bitcoinCore: bitcoinCore, initialBlockDownload: bitcoinCore.initialBlockDownload, peerTaskFactory: PeerTaskFactory(), masternodeListManager: masternodeListManager)

        bitcoinCore.add(peerTaskHandler: masternodeSyncer)
        bitcoinCore.add(peerSyncListener: masternodeSyncer)
        bitcoinCore.add(peerGroupListener: masternodeSyncer)
        self.masternodeSyncer = masternodeSyncer

// --------------------------------------
        let transactionLockVoteValidator = TransactionLockVoteValidator(storage: storage, hasher: singleHasher)
        let instantSendFactory = InstantSendFactory()
        let instantTransactionSyncer = InstantTransactionSyncer(transactionSyncer: bitcoinCore.transactionSyncer)
        let lockVoteManager = TransactionLockVoteManager(transactionLockVoteValidator: transactionLockVoteValidator)
        let instantTransactionState = InstantTransactionState()
        let instantTransactionManager = InstantTransactionManager(storage: storage, instantSendFactory: instantSendFactory, instantTransactionState: instantTransactionState)

        let instantSend = InstantSend(transactionSyncer: instantTransactionSyncer, lockVoteManager: lockVoteManager, instantTransactionManager: instantTransactionManager)

        bitcoinCore.add(peerTaskHandler: instantSend)
        bitcoinCore.add(inventoryItemsHandler: instantSend)
// --------------------------------------

    }

    public override func send(to address: String, value: Int, feeRate: Int) throws {
        try super.send(to: address, value: value, feeRate: 1)
    }

    public func transactions(fromHash: String?, limit: Int?) -> Single<[DashTransactionInfo]> {
        return super.transactions(fromHash: fromHash, limit: limit).map { $0.compactMap { $0 as? DashTransactionInfo } }
    }
}

public class DashTransactionInfo: TransactionInfo {
    public var instantTx: Bool = false

    public required init(transactionHash: String, transactionIndex: Int, from: [TransactionAddressInfo], to: [TransactionAddressInfo], amount: Int, blockHeight: Int?, timestamp: Int) {
        super.init(transactionHash: transactionHash, transactionIndex: transactionIndex, from: from, to: to, amount: amount, blockHeight: blockHeight, timestamp: timestamp)
    }

}