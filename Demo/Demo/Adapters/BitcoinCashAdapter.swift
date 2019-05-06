import BitcoinCashKit
import BitcoinCore
import RxSwift

class BitcoinCashAdapter: BaseAdapter {
    private let bitcoinCashKit: BitcoinCashKit

    init(words: [String], testMode: Bool) {
        let networkType: BitcoinCashKit.NetworkType = testMode ? .testNet : .mainNet
        bitcoinCashKit = try! BitcoinCashKit(withWords: words, walletId: "walletId", networkType: networkType, minLogLevel: Configuration.shared.minLogLevel)

        super.init(name: "Bitcoin Cash", coinCode: "BCH", abstractKit: bitcoinCashKit)
        bitcoinCashKit.delegate = self
    }

}

extension BitcoinCashAdapter: BitcoinCoreDelegate {

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
