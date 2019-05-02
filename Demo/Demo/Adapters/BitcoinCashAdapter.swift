import BitcoinCashKit
import RxSwift

class BitcoinCashAdapter: BaseAdapter {
    private let bitcoinCashKit: BitcoinCashKit

    init(words: [String], testMode: Bool) {
        let networkType: BitcoinCashKit.NetworkType = testMode ? .testNet : .mainNet
        bitcoinCashKit = try! BitcoinCashKit(withWords: words, walletId: "walletId", networkType: networkType, minLogLevel: .error)

        super.init(name: "Bitcoin Cash", coinCode: "BCH", abstractKit: bitcoinCashKit)
    }

}
