import LitecoinKit
import BitcoinCore
import HdWalletKit
import HsToolKit
import RxSwift

class LitecoinAdapter: BaseAdapter {
    let litecoinKit: LitecoinKit

    init(words: [String], bip: Bip, testMode: Bool, syncMode: BitcoinCore.SyncMode, logger: Logger) {
        let networkType: LitecoinKit.NetworkType = testMode ? .testNet : .mainNet
        litecoinKit = try! LitecoinKit(withWords: words, bip: bip, walletId: "walletId", syncMode: syncMode, networkType: networkType, confirmationsThreshold: 1, logger: logger.scoped(with: "LitecoinKit"))

        super.init(name: "Litecoin", coinCode: "LTC", abstractKit: litecoinKit)
        litecoinKit.delegate = self
    }

    class func clear() {
        try? LitecoinKit.clear()
    }
}

extension LitecoinAdapter: BitcoinCoreDelegate {

    func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSignal.notify()
    }

    func transactionsDeleted(hashes: [String]) {
        transactionsSignal.notify()
    }

    func balanceUpdated(balance: BalanceInfo) {
        balanceSignal.notify()
    }

    func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        syncStateSignal.notify()
    }

}
