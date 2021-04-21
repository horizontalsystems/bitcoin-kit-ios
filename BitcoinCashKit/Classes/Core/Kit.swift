import BitcoinCore
import HdWalletKit
import BigInt
import RxSwift
import HsToolKit

public class Kit: AbstractKit {
    private static let name = "BitcoinCashKit"
    private static let svChainForkHeight = 556767                                  // 2018 November 14
    private static let bchnChainForkHeight = 661648                                // 2020 November 15, 14:13 GMT
    private static let abcChainForkBlockHash = "0000000000000000004626ff6e3b936941d341c5932ece4357eeccac44e6d56c".reversedData!
    private static let bchnChainForkBlockHash = "0000000000000000029e471c41818d24b8b74c911071c4ef0b4a0509f9b5a8ce".reversedData!

    private static let legacyHeightInterval = 2016                                    // Default block count in difficulty change circle ( Bitcoin )
    private static let legacyTargetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. Bitcoin )
    private static let legacyMaxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks

    private static let heightInterval = 144                                     // Blocks count in window for calculating difficulty ( BitcoinCash )
    private static let targetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. same as Bitcoin )
    private static let maxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks

    public enum NetworkType {
        case mainNet(coinType: CoinType)
        case testNet

        var description: String {
            switch self {
            case .mainNet(let coinType):
                switch coinType {
                case .type0: return "mainNet" // back compatibility for database file name in old NetworkType
                case .type145: return "mainNet-145"
                }
            case .testNet:
                return "testNet"
            }
        }
    }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    public init(seed: Data, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet(coinType: .type145), confirmationsThreshold: Int = 6, logger: Logger?) throws {
        let network: INetwork
        let initialSyncApiUrl: String

        let validScheme: String
        switch networkType {
            case .mainNet(let coinType):
                network = MainNet(coinType: coinType)
                initialSyncApiUrl = "https://explorer.api.bitcoin.com/bch/v1"
                validScheme = "bitcoincash"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = "https://explorer.api.bitcoin.com/tbch/v1"
                validScheme = "bchtest"
        }

        let logger = logger ?? Logger(minLogLevel: .verbose)

        let initialSyncApi = InsightApi(url: initialSyncApiUrl, logger: logger)

        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name).appendingPathComponent(Kit.databaseFileName(walletId: walletId, networkType: networkType, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)
        let paymentAddressParser = PaymentAddressParser(validScheme: validScheme, removeScheme: false)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let coreBlockHelper = BlockValidatorHelper(storage: storage)
        let blockHelper = BitcoinCashBlockValidatorHelper(coreBlockValidatorHelper: coreBlockHelper)

        let daaValidator = DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, targetSpacing: Kit.targetSpacing, heightInterval: Kit.heightInterval)
        let asertValidator = ASERTValidator(encoder: difficultyEncoder)

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: ForkValidator(concreteValidator: asertValidator, forkHeight: Kit.bchnChainForkHeight, expectedBlockHash: Kit.bchnChainForkBlockHash))
            blockValidatorChain.add(blockValidator: asertValidator)
            blockValidatorChain.add(blockValidator: ForkValidator(concreteValidator: daaValidator, forkHeight: Kit.svChainForkHeight, expectedBlockHash: Kit.abcChainForkBlockHash))
            blockValidatorChain.add(blockValidator: daaValidator)
            blockValidatorChain.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: coreBlockHelper, heightInterval: Kit.legacyHeightInterval, targetTimespan: Kit.legacyTargetSpacing * Kit.legacyHeightInterval, maxTargetBits: Kit.legacyMaxTargetBits))
            blockValidatorChain.add(blockValidator: EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, blockMedianTimeHelper: BlockMedianTimeHelper(storage: storage), maxTargetBits: Kit.legacyMaxTargetBits))
        case .testNet: ()
                // not use test validators
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let bitcoinCore = try BitcoinCoreBuilder(logger: logger)
                .set(network: network)
                .set(initialSyncApi: initialSyncApi)
                .set(seed: seed)
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

extension Kit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.description)-\(syncMode)"
    }

}
