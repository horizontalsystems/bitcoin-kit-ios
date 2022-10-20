import BitcoinCore
import HdWalletKit
import BigInt
import RxSwift
import HsToolKit

public class Kit: AbstractKit {
    private static let heightInterval = 2016                                    // Default block count in difficulty change circle
    private static let targetSpacing = Int(2.5 * 60)                            // Time to mining one block
    private static let maxTargetBits = 0x1e0fffff                               // Initially and max. target difficulty for blocks

    private static let name = "LitecoinKit"

    public enum NetworkType: String, CaseIterable { case mainNet, testNet }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    public init(seed: Data, bip: Bip, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, logger: Logger?) throws {
        let network: INetwork
        let initialSyncApiUrl: String

        switch networkType {
            case .mainNet:
                network = MainNet()
                initialSyncApiUrl = "https://ltc.horizontalsystems.xyz/api"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = ""
        }

        let logger = logger ?? Logger(minLogLevel: .verbose)

        let initialSyncApi = BCoinApi(url: initialSyncApiUrl, logger: logger)

        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name).appendingPathComponent(Kit.databaseFileName(walletId: walletId, networkType: networkType, bip: bip, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)

        let paymentAddressParser = PaymentAddressParser(validScheme: "litecoin", removeScheme: true)
        let scriptConverter = ScriptConverter()
        let bech32AddressConverter = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)
        let base58AddressConverter = Base58AddressConverter(addressVersion: network.pubKeyHash, addressScriptVersion: network.scriptHash)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        let scryptHasher = ScryptHasher()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(hasher: scryptHasher, difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let blockHelper = BlockValidatorHelper(storage: storage)

        let difficultyAdjustmentValidator = LegacyDifficultyAdjustmentValidator(
                encoder: difficultyEncoder,
                blockValidatorHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetTimespan: Kit.heightInterval * Kit.targetSpacing,
                maxTargetBits: Kit.maxTargetBits
        )

        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: difficultyAdjustmentValidator)
            blockValidatorChain.add(blockValidator: BitsValidator())
        case .testNet:
            blockValidatorChain.add(blockValidator: difficultyAdjustmentValidator)
            blockValidatorChain.add(blockValidator: LegacyTestNetDifficultyValidator(blockHelper: blockHelper, heightInterval: Kit.heightInterval, targetSpacing: Kit.targetSpacing, maxTargetBits: Kit.maxTargetBits))
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let bitcoinCore = try BitcoinCoreBuilder(logger: logger)
                .set(network: network)
                .set(initialSyncApi: initialSyncApi)
                .set(seed: seed)
                .set(bip: bip)
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

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        switch bip {
        case .bip44:
            bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58AddressConverter))
        case .bip49:
            bitcoinCore.add(restoreKeyConverter: Bip49RestoreKeyConverter(addressConverter: base58AddressConverter))
        case .bip84:
            bitcoinCore.add(restoreKeyConverter: KeyHashRestoreKeyConverter())
        }
    }

}

extension Kit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, bip: Bip, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.rawValue)-\(bip.description)-\(syncMode)"
    }

}
