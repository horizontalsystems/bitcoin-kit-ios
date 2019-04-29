import BitcoinCore
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
    private let bech32AddressConverter: IAddressConverter

    public init(withWords words: [String], walletId: String, newWallet: Bool = false, networkType: NetworkType = .mainNet, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork
        var initialSyncApiUrl: String? = nil

        switch networkType {
            case .mainNet:
                network = MainNet()
                initialSyncApiUrl = "https://btc.horizontalsystems.xyz/apg"
            case .testNet:
                network = TestNet()
                initialSyncApiUrl = "http://btc-testnet.horizontalsystems.xyz/apg"
            case .regTest: network = RegTest()
        }

        let databaseFileName = "\(walletId)-bitcoin-\(networkType)"

        let storage = GrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)
        let addressSelector = BitcoinAddressSelector()

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
                .set(network: network)
                .set(initialSyncApiUrl: initialSyncApiUrl)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(walletId: walletId)
                .set(peerSize: 10)
                .set(newWallet: newWallet)
                .set(storage: storage)
                .build()

        let scriptConverter = ScriptConverter()
        bech32AddressConverter = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)

        super.init(bitcoinCore: bitcoinCore, network: network)

        // extending BitcoinCore

        bitcoinCore.prepend(scriptBuilder: SegWitScriptBuilder())
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
    }

    override open var debugInfo: String {
        var lines = [String](arrayLiteral: bitcoinCore.debugInfo)
        let pubKeys = storage.publicKeys().sorted(by: { $0.index < $1.index })

        lines.append("--------------- Bitcoin Segwit (zero program) addresses --------------------")
        for pubKey in pubKeys {
            lines.append("acc: \(pubKey.account) - inx: \(pubKey.index) - ext: \(pubKey.external) : \(try! bech32AddressConverter.convert(keyHash: Data(bytes: [0x00, 0x14]) + pubKey.keyHash, type: .p2wpkh).stringValue)") 
        }

        return lines.joined(separator: "\n")
    }

}
