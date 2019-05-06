import BitcoinCore
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinCashKit: AbstractKit {
    private static let heightInterval = 144                                     // Blocks count in window for calculating difficulty ( BitcoinCash )
    private static let targetSpacing = 10 * 60                                  // Time to mining one block ( 10 min. same as Bitcoin )
    private static let maxTargetBits = 0x1d00ffff                               // Initially and max. target difficulty for blocks

    public enum NetworkType { case mainNet, testNet }

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            bitcoinCore.delegate = delegate
        }
    }

    private let storage: IBitcoinCashStorage

    public init(withWords words: [String], walletId: String, newWallet: Bool = false, networkType: NetworkType = .mainNet, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        let initialSyncApiUrl: String

        let validScheme: String
        switch networkType {
            case .mainNet:
                network = MainNet()
                initialSyncApiUrl = "https://bch.horizontalsystems.xyz/apg"
                validScheme = "bitcoincash"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = "http://bch-testnet.horizontalsystems.xyz/apg"
                validScheme = "bchtest"
        }

        let databaseFileName = "\(walletId)-bitcoincash-\(networkType)"

        let storage = BitcoinCashGrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: validScheme, removeScheme: false)
        let addressSelector = BitcoinCashAddressSelector()

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
                .set(network: network)
                .set(initialSyncApiUrl: initialSyncApiUrl)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(walletId: walletId)
                .set(peerSize: 4)
                .set(newWallet: newWallet)
                .set(storage: storage)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore
        let bech32 = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        bitcoinCore.prepend(addressConverter: bech32)

        let coreBlockHelper = BlockValidatorHelper(storage: storage)
        let blockHelper = BitcoinCashBlockValidatorHelper(storage: storage, coreBlockValidatorHelper: coreBlockHelper)
        let difficultyEncoder = DifficultyEncoder()

        switch networkType {
        case .mainNet:
            bitcoinCore.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: coreBlockHelper, heightInterval: BitcoinCore.heightInterval, targetTimespan: BitcoinCore.targetSpacing * BitcoinCore.heightInterval, maxTargetBits: BitcoinCore.maxTargetBits))
            bitcoinCore.add(blockValidator: DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, targetSpacing: BitcoinCashKit.targetSpacing, heightInterval: BitcoinCashKit.heightInterval, firstCheckpointHeight: network.checkpointBlock.height))
            bitcoinCore.add(blockValidator: EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, maxTargetBits: BitcoinCore.maxTargetBits))
        case .testNet: ()
            // not use test validators
        }
    }

}
