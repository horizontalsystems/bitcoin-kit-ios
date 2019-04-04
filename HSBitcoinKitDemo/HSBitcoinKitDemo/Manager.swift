import Foundation
import HSBitcoinKit
import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    var kit: BitcoinKit!

    let kitInitializationCompleted = BehaviorSubject<Bool>(value: false)

    let balanceSubject = PublishSubject<Int>()
    let lastBlockInfoSubject = PublishSubject<BlockInfo>()
    let progressSubject = PublishSubject<BitcoinCore.KitState>()
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
            try kit.clear()
        } catch {
            print("WalletKit Clear Error: \(error)")
        }

        clearWords()

        kitInitializationCompleted.onNext(false)
        kit = nil
    }

    private func initWalletKit(words: [String]) {
        kit = try! BitcoinKit(withWords: words, walletId: "SomeId", testMode: true, minLogLevel: .verbose)
        kit.delegate = self

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

extension Manager: BitcoinCoreDelegate {
    public func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        transactionsSubject.onNext(())
    }

    public func balanceUpdated(balance: Int) {
        balanceSubject.onNext(balance)
    }

    public func transactionsDeleted(hashes: [String]) {
        // transactionsSubject.onNext(())
    }

    public func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        lastBlockInfoSubject.onNext(lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        progressSubject.onNext(state)
    }

}
