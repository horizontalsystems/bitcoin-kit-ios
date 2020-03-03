import BitcoinCore
import HdWalletKit
import BigInt
import RxSwift

public class BitcoinCashKit: AbstractKit {
    private static let name = "BitcoinCashKit"
    private static let svChainForkHeight = 556767                                  // 2018 November 14
    private static let abcChainForkBlockHash = "0000000000000000004626ff6e3b936941d341c5932ece4357eeccac44e6d56c".reversedData!


    private static let heightInterval = 144                                     // Blocks count in window for calculating difficulty ( BitcoinCash )
    private static let targetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. same as Bitcoin )
    private static let maxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks

    public enum NetworkType: String, CaseIterable { case mainNet, testNet }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    public init(withWords words: [String], walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        let initialSyncApiUrl: String

        let validScheme: String
        switch networkType {
            case .mainNet:
                network = MainNet()
                initialSyncApiUrl = "https://cashexplorer.bitcoin.com/api"
                validScheme = "bitcoincash"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = "https://tbch.blockdozer.com/api/" //not working
                validScheme = "bchtest"
        }
        let initialSyncApi = InsightApi(url: initialSyncApiUrl)

        let databaseFilePath = try DirectoryHelper.directoryURL(for: BitcoinCashKit.name).appendingPathComponent(BitcoinCashKit.databaseFileName(walletId: walletId, networkType: networkType, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)
        let paymentAddressParser = PaymentAddressParser(validScheme: validScheme, removeScheme: false)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let coreBlockHelper = BlockValidatorHelper(storage: storage)
        let blockHelper = BitcoinCashBlockValidatorHelper(coreBlockValidatorHelper: coreBlockHelper)

        let daaValidator = DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, targetSpacing: BitcoinCashKit.targetSpacing, heightInterval: BitcoinCashKit.heightInterval, firstCheckpointHeight: network.lastCheckpointBlock.height)

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: ForkValidator(concreteValidator: daaValidator, forkHeight: BitcoinCashKit.svChainForkHeight, expectedBlockHash: BitcoinCashKit.abcChainForkBlockHash))
            blockValidatorChain.add(blockValidator: daaValidator)
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: coreBlockHelper, heightInterval: BitcoinCore.heightInterval, targetTimespan: BitcoinCore.targetSpacing * BitcoinCore.heightInterval, maxTargetBits: BitcoinCore.maxTargetBits))
            blockValidatorChain.add(blockValidator: EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, blockMedianTimeHelper: BlockMedianTimeHelper(storage: storage), maxTargetBits: BitcoinCore.maxTargetBits, firstCheckpointHeight: network.bip44CheckpointBlock.height))
        case .testNet: ()
                // not use test validators
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
                .set(network: network)
                .set(initialSyncApi: initialSyncApi)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(walletId: walletId)
                .set(confirmationsThreshold: confirmationsThreshold)
                .set(peerSize: 10)
                .set(syncMode: syncMode)
                .set(storage: storage)
                .set(blockValidator: blockValidatorSet)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore
        let bech32 = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        let base58 = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)
        bitcoinCore.prepend(addressConverter: bech32)

        bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58))
    }

}

extension BitcoinCashKit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: BitcoinCashKit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.rawValue)-\(syncMode)"
    }

}
