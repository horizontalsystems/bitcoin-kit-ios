import Foundation
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinKit: AbstractKit {
    public enum NetworkType { case mainNet, testNet, regTest }

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
        switch networkType {
            case .mainNet: network = BitcoinMainNet()
            case .testNet: network = BitcoinTestNet()
            case .regTest: network = BitcoinRegTest()
        }

        let databaseFileName = "\(walletId)-bitcoin-\(networkType)"

        let storage = GrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
        let addressSelector = BitcoinAddressSelector()
        let apiFeeRateResource = "BTC"

        let bitcoinCore = try BitcoinCoreBuilder()
                .set(network: network)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(feeRateApiResource: apiFeeRateResource)
                .set(walletId: walletId)
                .set(peerSize: 10)
                .set(newWallet: false)
                .set(storage: storage)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore
        let scriptConverter = ScriptConverter()
        let bech32 = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)

        bitcoinCore.prepend(addressConverter: bech32)

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
    }

}
