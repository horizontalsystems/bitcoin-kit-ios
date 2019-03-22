import Foundation
import HSBitcoinKit
import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let coin: BitcoinKit.Coin = .bitcoin(network: .testNet)

    var bitcoinKit: BitcoinKit!

    let kitInitializationCompleted = BehaviorSubject<Bool>(value: false)

    let balanceSubject = PublishSubject<Int>()
    let lastBlockInfoSubject = PublishSubject<BlockInfo>()
    let progressSubject = PublishSubject<BitcoinKit.KitState>()
    let transactionsSubject = PublishSubject<Void>()

    init() {
        if let words = savedWords {
            initWalletKit(words: words)
        }
    }

    func login(words: [String]) {
        save(words: words)
        initWalletKit(words: words)
    }

    func logout() {
        do {
            try bitcoinKit.clear()
        } catch {
            print("WalletKit Clear Error: \(error)")
        }

        clearWords()

        kitInitializationCompleted.onNext(false)
        bitcoinKit = nil
    }

    private func initWalletKit(words: [String]) {
        bitcoinKit = BitcoinKit(withWords: words, coin: self.coin, walletId: "SomeId", confirmationsThreshold: 1)
        bitcoinKit.delegate = self

        kitInitializationCompleted.onNext(true)
    }

    private var savedWords: [String]? {
        if let wordsString = UserDefaults.standard.value(forKey: keyWords) as? String {
            return wordsString.split(separator: " ").map(String.init)
        }
        return nil
    }

    private func save(words: [String]) {
        UserDefaults.standard.set(words.joined(separator: " "), forKey: keyWords)
        UserDefaults.standard.synchronize()
    }

    private func clearWords() {
        UserDefaults.standard.removeObject(forKey: keyWords)
        UserDefaults.standard.synchronize()
    }

}

extension Manager: BitcoinKitDelegate {

    public func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSubject.onNext(())
    }

    public func transactionsDeleted(hashes: [String]) {
        // transactionsSubject.onNext(())
    }

    public func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int) {
        balanceSubject.onNext(balance)
    }

    public func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo) {
        lastBlockInfoSubject.onNext(lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinKit.KitState) {
        progressSubject.onNext(state)
    }

}
