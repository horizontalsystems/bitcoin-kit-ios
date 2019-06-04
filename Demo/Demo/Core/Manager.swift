import RxSwift
import BitcoinCore

class Manager {
    static let shared = Manager()

    private let keyWords = "mnemonic_words"

    let adapterSignal = Signal()
    var adapters = [BaseAdapter]()

    init() {
        if let words = savedWords {
            DispatchQueue.global(qos: .userInitiated).async {
                self.initAdapters(words: words, syncMode: .api)
            }
        }
    }

    func login(words: [String], syncModeStr: String) {
        save(words: words)
        clearKits()

        let syncMode: BitcoinCore.SyncMode
        if syncModeStr == "full" {
            syncMode = .full
        } else {
            syncMode = .api
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.initAdapters(words: words, syncMode: syncMode)
        }
    }

    func logout() {
        clearWords()
        adapters = []
    }

    private func initAdapters(words: [String], syncMode: BitcoinCore.SyncMode) {
        let configuration = Configuration.shared

        adapters = [
            BitcoinAdapter(words: words, testMode: configuration.testNet, syncMode: syncMode),
            BitcoinCashAdapter(words: words, testMode: configuration.testNet, syncMode: syncMode),
            DashAdapter(words: words, testMode: configuration.testNet, syncMode: syncMode),
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
