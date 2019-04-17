import Foundation
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
            guard let delegate = delegate else {
                return
            }
            bitcoinCore.add(delegate: delegate)
        }
    }

    private let storage: IStorage

    public init(withWords words: [String], walletId: String, networkType: NetworkType = .mainNet, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        let validScheme: String
        switch networkType {
            case .mainNet:
                network = BitcoinCashMainNet()
                validScheme = "bitcoincash"
            case .testNet:
                network = BitcoinCashTestNet()
                validScheme = "bchtest"
        }

        let databaseFileName = "\(walletId)-bitcoincash-\(networkType)"

        let storage = GrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: validScheme, removeScheme: false)
        let addressSelector = BitcoinCashAddressSelector()
        let apiFeeRateResource = "BCH"

        let bitcoinCore = try BitcoinCoreBuilder()
                .set(network: network)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(feeRateApiResource: apiFeeRateResource)
                .set(walletId: walletId)
                .set(peerSize: 4)
                .set(newWallet: false)
                .set(storage: storage)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore
        let bech32 = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        bitcoinCore.prepend(addressConverter: bech32)

        let blockHelper = BitcoinCashBlockValidatorHelper(storage: storage)
        let difficultyEncoder = DifficultyEncoder()

        switch networkType {
        case .mainNet:
            bitcoinCore.add(blockValidator: LegacyDifficultyAdjustmentValidator(encoder: difficultyEncoder, blockValidatorHelper: blockHelper, heightInterval: BitcoinCore.heightInterval, targetTimespan: BitcoinCore.targetSpacing * BitcoinCore.heightInterval, maxTargetBits: BitcoinCore.maxTargetBits))
            bitcoinCore.add(blockValidator: DAAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, targetSpacing: BitcoinCashKit.targetSpacing, heightInterval: BitcoinCashKit.heightInterval, firstCheckpointHeight: network.checkpointBlock.height))
            bitcoinCore.add(blockValidator: EDAValidator(encoder: difficultyEncoder, blockHelper: blockHelper, maxTargetBits: BitcoinCore.maxTargetBits))
        case .testNet: ()
            // not use test validators
        }
    }

}
