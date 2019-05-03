import DashKit
import RxSwift

class DashAdapter: BaseAdapter {
    private let dashKit: DashKit

    init(words: [String], testMode: Bool) {
        let networkType: DashKit.NetworkType = testMode ? .testNet : .mainNet
        dashKit = try! DashKit(withWords: words, walletId: "walletId", networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Dash", coinCode: "DASH", abstractKit: dashKit)
    }

}
