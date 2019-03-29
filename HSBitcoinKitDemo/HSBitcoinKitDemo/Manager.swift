import Foundation
import HSBitcoinKit
import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let coin: BitcoinKit.Coin = .dash(network: .testNet)

    var dashKit: DashKit!

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
            try dashKit.clear()
        } catch {
            print("WalletKit Clear Error: \(error)")
        }

        clearWords()

        kitInitializationCompleted.onNext(false)
        dashKit = nil
    }

    private func initWalletKit(words: [String]) {
        dashKit = DashKit(withWords: words, coin: self.coin, walletId: "SomeId", newWallet: true, confirmationsThreshold: 1)
        dashKit.delegate = self

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

extension Manager: DashKitDelegate {
    public func transactionsUpdated(BitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSubject.onNext(())
    }

    public func balanceUpdated(BitcoinKit: BitcoinKit, balance: Int) {
        balanceSubject.onNext(balance)
    }

    public func transactionsDeleted(hashes: [String]) {
        // transactionsSubject.onNext(())
    }

    public func lastBlockInfoUpdated(BitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo) {
        lastBlockInfoSubject.onNext(lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinKit.KitState) {
        progressSubject.onNext(state)
    }

}
