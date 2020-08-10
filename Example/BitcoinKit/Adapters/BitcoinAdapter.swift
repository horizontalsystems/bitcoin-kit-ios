import BitcoinKit
import BitcoinCore
import HdWalletKit
import HsToolKit
import RxSwift

class BitcoinAdapter: BaseAdapter {
    let bitcoinKit: BitcoinKit

    init(words: [String], bip: Bip, testMode: Bool, syncMode: BitcoinCore.SyncMode, logger: Logger) {
        let networkType: BitcoinKit.NetworkType = testMode ? .testNet : .mainNet
        bitcoinKit = try! BitcoinKit(withWords: words, bip: bip, walletId: "walletId", syncMode: syncMode, networkType: networkType, confirmationsThreshold: 1, logger: logger.scoped(with: "BitcoinKit"))

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
