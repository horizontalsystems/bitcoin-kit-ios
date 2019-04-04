import Foundation
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinKit: AbstractKit {

    public weak var delegate: BitcoinCoreDelegate? {
        didSet {
            guard let delegate = delegate else {
                return
            }
            bitcoinCore.add(delegate: delegate)
        }
    }

    private let storage: IStorage

    public init(withWords words: [String], walletId: String, testMode: Bool = false, minLogLevel: Logger.Level = .verbose) throws {
        let network: INetwork = testMode ? BitcoinTestNet() : BitcoinMainNet()

        let databaseFileName = "\(walletId)-bitcoin-\(testMode ? "test" : "")"

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

        extend(bitcoinCore: bitcoinCore)
    }

    func extend(bitcoinCore: BitcoinCore) {
        let scriptConverter = ScriptConverter()
        let bech32 = SegWitBech32AddressConverter(prefix: network.bech32PrefixPattern, scriptConverter: scriptConverter)

        bitcoinCore.prepend(addressConverter: bech32)
    }

}
