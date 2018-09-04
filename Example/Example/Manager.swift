import Foundation
import WalletKit
import RealmSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let networkType: WalletKit.NetworkType = .bitcoinRegTest

    var walletKit: WalletKit!

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
            try walletKit.clear()
        } catch {
            print("WalletKit Clear Error: \(error)")
        }

        clearWords()
        walletKit = nil
    }

    private func initWalletKit(words: [String]) {
        let wordsHash = words.joined()
        let realmFileName = "\(wordsHash)-\(networkType).realm"

        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let realmConfiguration = Realm.Configuration(fileURL: documentsUrl?.appendingPathComponent(realmFileName))

        walletKit = WalletKit(withWords: words, realmConfiguration: realmConfiguration, networkType: networkType)
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
