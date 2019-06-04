import BitcoinKit
import BitcoinCore
import RxSwift

class BitcoinAdapter: BaseAdapter {
    private let bitcoinKit: BitcoinKit
    override var changeableAddressType: Bool { return true }

    init(words: [String], testMode: Bool, syncMode: BitcoinCore.SyncMode) {
        let networkType: BitcoinKit.NetworkType = testMode ? .testNet : .mainNet
        bitcoinKit = try! BitcoinKit(withWords: words, walletId: "walletId", syncMode: syncMode, networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Bitcoin", coinCode: "BTC", abstractKit: bitcoinKit)
        bitcoinKit.delegate = self
    }

    class func clear() {
        try? BitcoinKit.clear()
    }
}

extension BitcoinAdapter: BitcoinCoreDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSignal.notify()
    }

    func transactionsDeleted(hashes: [String]) {
        transactionsSignal.notify()
    }

    func balanceUpdated(balance: Int) {
        balanceSignal.notify()
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        syncStateSignal.notify()
    }

}
