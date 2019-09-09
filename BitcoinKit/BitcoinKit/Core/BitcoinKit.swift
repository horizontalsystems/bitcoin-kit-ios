import BitcoinCore
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinKit: AbstractKit {
    private static let name = "BitcoinKit"

    public enum NetworkType: String, CaseIterable { case mainNet, testNet, regTest }

    private let storage: IStorage
    private let bech32AddressConverter: IAddressConverter

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

        let databaseFilePath = try DirectoryHelper.directoryURL(for: BitcoinKit.name).appendingPathComponent(BitcoinKit.databaseFileName(walletId: walletId, networkType: networkType)).path
        let storage = GrdbStorage(databaseFilePath: databaseFilePath)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: "bitcoin", removeScheme: true)

        let bitcoinCore = try BitcoinCoreBuilder(minLogLevel: minLogLevel)
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

        bitcoinCore.add(restoreKeyConverterForBip: bip)
        if bip == .bip44 {
            bitcoinCore.add(restoreKeyConverterForBip: .bip49)
            bitcoinCore.add(restoreKeyConverterForBip: .bip84)
        }
    }

    override open var debugInfo: String {
        var lines = [String](arrayLiteral: bitcoinCore.debugInfo)
        let pubKeys = storage.publicKeys().sorted(by: { $0.index < $1.index })

        lines.append("--------------- Bitcoin Segwit (zero program) addresses --------------------")
        for pubKey in pubKeys {
            lines.append("acc: \(pubKey.account) - inx: \(pubKey.index) - ext: \(pubKey.external) : \(try! bech32AddressConverter.convert(keyHash: Data([0x00, 0x14]) + pubKey.keyHash, type: .p2wpkh).stringValue)") 
        }

        return lines.joined(separator: "\n")
    }

}

extension BitcoinKit {

    public static func clear(exceptFor walletIdsToExclude: [String] = []) throws {
        var excludedFileNames = [String]()

        for walletId in walletIdsToExclude {
            for type in NetworkType.allCases {
                excludedFileNames.append(databaseFileName(walletId: walletId, networkType: type))
            }
        }

        try DirectoryHelper.removeAll(inDirectory: BitcoinKit.name, except: excludedFileNames)
    }

    private static func databaseFileName(walletId: String, networkType: NetworkType) -> String {
        return "\(walletId)-\(networkType.rawValue)"
    }

}
