import BitcoinKit
import RxSwift

class BitcoinAdapter: BaseAdapter {
    private let bitcoinKit: BitcoinKit

    init(words: [String], testMode: Bool) {
        let networkType: BitcoinKit.NetworkType = testMode ? .testNet : .mainNet
        bitcoinKit = try! BitcoinKit(withWords: words, walletId: "walletId", networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Bitcoin", coinCode: "BTC", abstractKit: bitcoinKit)
    }

}
