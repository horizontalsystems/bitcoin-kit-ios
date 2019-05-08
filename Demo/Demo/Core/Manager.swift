import RxSwift

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let adapterSignal = Signal()
    var adapters = [BaseAdapter]()

    init() {
        if let words = savedWords {
            DispatchQueue.global(qos: .userInitiated).async {
                self.initAdapters(words: words)
            }
        }
    }

    func login(words: [String]) {
        save(words: words)
        clearKits()

        DispatchQueue.global(qos: .userInitiated).async {
            self.initAdapters(words: words)
        }
    }

    func logout() {
        clearWords()
        adapters = []
    }

    private func initAdapters(words: [String]) {
        let configuration = Configuration.shared

        adapters = [
            BitcoinAdapter(words: words, testMode: configuration.testNet),
            BitcoinCashAdapter(words: words, testMode: configuration.testNet),
            DashAdapter(words: words, testMode: configuration.testNet),
        ]

        adapterSignal.notify()
    }

    var savedWords: [String]? {
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

    private func clearKits() {
        BitcoinAdapter.clear()
        BitcoinCashAdapter.clear()
        DashAdapter.clear()
    }

}
