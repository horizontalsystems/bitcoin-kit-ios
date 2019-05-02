import DashKit
import RxSwift

class DashAdapter: BaseAdapter {
    private let dashKit: DashKit

    init(words: [String], testMode: Bool) {
        let networkType: DashKit.NetworkType = testMode ? .testNet : .mainNet
        dashKit = try! DashKit(withWords: words, walletId: "walletId", networkType: networkType, minLogLevel: .error)

        super.init(name: "Dash", coinCode: "DASH", abstractKit: dashKit)
    }

}
