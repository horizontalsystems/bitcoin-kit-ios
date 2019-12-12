import BitcoinCore
import HSHDWalletKit
import Hodler
import BigInt
import RxSwift

public class BitcoinKit: AbstractKit {
    private static let name = "BitcoinKit"

    public enum NetworkType: String, CaseIterable { case mainNet, testNet, regTest }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    public init(withWords words: [String], bip: Bip, walletId: String, syncMode: BitcoinCore.SyncMode = .api, networkType: NetworkType = .mainNet, confirmationsThreshold: Int = 6, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        let initialSyncApiUrl: String

        switch networkType {
            case .mainNet:
                network = MainNet()
                initialSyncApiUrl = "https://btc.horizontalsystems.xyz/apg"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = "http://btc-testnet.horizontalsystems.xyz/apg"
            case .regTest:
                network = RegTest()
                initialSyncApiUrl = ""
        }
        let initialSyncApi = BCoinApi(url: initialSyncApiUrl)

        let databaseFilePath = try DirectoryHelper.directoryURL(for: BitcoinKit.name).appendingPathComponent(BitcoinKit.databaseFileName(walletId: walletId, networkType: networkType, bip: bip, syncMode: syncMode)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
        let scriptConverter = ScriptConverter()
        let bech32AddressConverter = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)

        let bitcoinCoreBuilder = BitcoinCoreBuilder(minLogLevel: minLogLevel)

        let hodler = HodlerPlugin(addressConverter: bitcoinCoreBuilder.addressConverter, blockMedianTimeHelper: BlockMedianTimeHelper(storage: storage), publicKeyStorage: storage)
        
        let bitcoinCore = try bitcoinCoreBuilder
                .set(network: network)
                .set(initialSyncApi: initialSyncApi)
                .set(words: words)
                .set(bip: bip)
                .set(paymentAddressParser: paymentAddressParser)
                .set(walletId: walletId)
                .set(confirmationsThreshold: confirmationsThreshold)
                .set(peerSize: 10)
                .set(syncMode: syncMode)
                .set(storage: storage)
                .add(plugin: hodler)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore

        bitcoinCore.prepend(addressConverter: bech32AddressConverter)

        let blockHelper = BlockValidatorHelper(storage: storage)
        let difficultyEncoder = DifficultyEncoder()

        switch networkType {
        case .mainNet:
            bitcoinCore.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: blockHelper, heightInterval: BitcoinCore.heightInterval, targetTimespan: BitcoinCore.heightInterval * BitcoinCore.targetSpacing, maxTargetBits: BitcoinCore.maxTargetBits))
            bitcoinCore.add(blockValidator: BitsValidator())
        case .regTest, .testNet:
            bitcoinCore.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: blockHelper, heightInterval: BitcoinCore.heightInterval, targetTimespan: BitcoinCore.heightInterval * BitcoinCore.targetSpacing, maxTargetBits: BitcoinCore.maxTargetBits))
            bitcoinCore.add(blockValidator: LegacyTestNetDifficultyValidator(blockHelper: blockHelper, heightInterval: BitcoinCore.heightInterval, targetSpacing: BitcoinCore.targetSpacing, maxTargetBits: BitcoinCore.maxTargetBits))
        }

        bitcoinCore.add(restoreKeyConverterForBip: bip)
        if bip == .bip44 {
            bitcoinCore.add(restoreKeyConverterForBip: .bip49)
            bitcoinCore.add(restoreKeyConverterForBip: .bip84)
        }
    }

}

extension BitcoinKit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: BitcoinKit.name, except: walletIdsToExclude)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType, bip: Bip, syncMode: BitcoinCore.SyncMode) -> String {
        "\(walletId)-\(networkType.rawValue)-\(bip.description)-\(syncMode)"
    }

}
