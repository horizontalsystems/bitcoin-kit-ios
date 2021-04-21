import BitcoinCashKit
import BitcoinCore
import HsToolKit
import RxSwift
import HdWalletKit

class BitcoinCashAdapter: BaseAdapter {
    let bitcoinCashKit: Kit

    init(words: [String], testMode: Bool, syncMode: BitcoinCore.SyncMode, logger: Logger) {
        let networkType: Kit.NetworkType = testMode ? .testNet : .mainNet(coinType: .type145)
        let seed = Mnemonic.seed(mnemonic: words)
        bitcoinCashKit = try! Kit(seed: seed, walletId: "walletId", syncMode: syncMode, networkType: networkType, logger: logger.scoped(with: "BitcoinCashKit"))

        super.init(name: "Bitcoin Cash", coinCode: "BCH", abstractKit: bitcoinCashKit)
        bitcoinCashKit.delegate = self
    }

    class func clear() {
        try? Kit.clear()
    }
}

extension BitcoinCashAdapter: BitcoinCoreDelegate {

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
