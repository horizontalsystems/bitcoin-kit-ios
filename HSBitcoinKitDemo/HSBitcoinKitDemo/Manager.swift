import Foundation
import HSBitcoinKit
import RealmSwift
import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let networkType: BitcoinKit.NetworkType = .bitcoinRegTest

    var bitcoinKit: BitcoinKit!

    let balanceSubject = PublishSubject<Int>()
    let lastBlockInfoSubject = PublishSubject<BlockInfo>()
    let progressSubject = PublishSubject<Double>()
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
        bitcoinKit = nil
    }

    private func initWalletKit(words: [String]) {
        bitcoinKit = BitcoinKit(withWords: words, networkType: networkType)
        bitcoinKit.delegate = self
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

    public func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int]) {
        transactionsSubject.onNext(())
    }

    public func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int) {
        balanceSubject.onNext(balance)
    }

    public func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo) {
        lastBlockInfoSubject.onNext(lastBlockInfo)
    }

    public func progressUpdated(bitcoinKit: BitcoinKit, progress: Double) {
        progressSubject.onNext(progress)
    }

}
