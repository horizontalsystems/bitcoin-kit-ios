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
        let apiFeeRateResource = testMode ? "BTC/testnet" : "BTC"

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

extension BitcoinKit {

//    public var lastBlockInfo: BlockInfo? {
//        return bitcoinCore.lastBlockInfo
//    }
//
//    public var balance: Int {
//        return bitcoinCore.balance
//    }
//
//    public var syncState: BitcoinCore.KitState {
//        return bitcoinCore.syncState
//    }
//
//    public func transactions(fromHash: String? = nil, limit: Int? = nil) -> Single<[TransactionInfo]> {
//        return bitcoinCore.transactions(fromHash: fromHash, limit: limit)
//    }
//
//    public func send(to address: String, value: Int) throws {
//        return try bitcoinCore.send(to: address, value: value)
//    }
//
//    public func validate(address: String) throws {
//        return try bitcoinCore.validate(address: address)
//    }
//
//    public func parse(paymentAddress: String) -> BitcoinPaymentData {
//        return bitcoinCore.parse(paymentAddress: paymentAddress)
//    }
//
//    public func fee(for value: Int, toAddress: String?, senderPay: Bool) throws -> Int {
//        return try bitcoinCore.fee(for: value, toAddress: toAddress, senderPay: senderPay)
//    }
//
//    public var receiveAddress: String {
//        return bitcoinCore.receiveAddress
//    }
//
//    public var debugInfo: String {
//        return bitcoinCore.debugInfo
//    }

}
