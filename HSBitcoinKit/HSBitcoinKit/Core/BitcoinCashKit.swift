import Foundation
import HSHDWalletKit
import BigInt
import HSCryptoKit
import RxSwift

public class BitcoinCashKit: AbstractKit {

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
        let network: INetwork = testMode ? BitcoinCashTestNet() : BitcoinCashMainNet()

        let databaseFileName = "\(walletId)-bitcoincash-\(testMode ? "test" : "")"

        let storage = GrdbStorage(databaseFileName: databaseFileName)
        self.storage = storage

        let paymentAddressParser = PaymentAddressParser(validScheme: testMode ? "bchtest" : "bitcoincash", removeScheme: false)
        let addressSelector = BitcoinCashAddressSelector()
        let apiFeeRateResource = "BCH"

        let bitcoinCore = try BitcoinCoreBuilder()
                .set(network: network)
                .set(words: words)
                .set(paymentAddressParser: paymentAddressParser)
                .set(addressSelector: addressSelector)
                .set(feeRateApiResource: apiFeeRateResource)
                .set(walletId: walletId)
                .set(peerSize: 2)
                .set(newWallet: false)
                .set(storage: storage)
                .build()

        super.init(bitcoinCore: bitcoinCore, network: network)

        extend(bitcoinCore: bitcoinCore)
    }

    func extend(bitcoinCore: BitcoinCore) {
        let bech32 = CashBech32AddressConverter(prefix: network.bech32PrefixPattern)
        bitcoinCore.prepend(addressConverter: bech32)
    }

}
