import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    var adapters: [BaseAdapter]!

    init() {
        if let words = savedWords {
            initAdapters(words: words)
        }
    }

    func login(words: [String]) {
        save(words: words)
        initAdapters(words: words)
    }

    func logout() {
        clearWords()

        adapters.forEach { $0.clear() }
        adapters = nil
    }

    private func initAdapters(words: [String]) {
        let configuration = Configuration.shared

        adapters = [
            BitcoinAdapter(words: words, testMode: configuration.testNet),
            BitcoinCashAdapter(words: words, testMode: configuration.testNet),
            DashAdapter(words: words, testMode: configuration.testNet),
        ]
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
