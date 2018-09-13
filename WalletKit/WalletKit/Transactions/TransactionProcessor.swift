import Foundation
import RealmSwift
import RxSwift

class TransactionProcessor {
    private let realmFactory: RealmFactory
    private let extractor: TransactionExtractor
    private let linker: TransactionLinker
    private let addressManager: AddressManager
    private let queue: DispatchQueue

    init(realmFactory: RealmFactory, extractor: TransactionExtractor, linker: TransactionLinker, addressManager: AddressManager, queue: DispatchQueue = DispatchQueue(label: "TransactionWorker", qos: .background)) {
        self.realmFactory = realmFactory
        self.extractor = extractor
        self.linker = linker
        self.addressManager = addressManager
        self.queue = queue
    }

    func enqueueRun() {
        queue.async {
            do {
                try self.run()
            } catch {
                Logger.shared.log(self, "\(error)")
            }
        }
    }

    private func run() throws {
        let realm = realmFactory.realm

        let unprocessedTransactions = realm.objects(Transaction.self).filter("processed = %@", false)

        if !unprocessedTransactions.isEmpty {
            try realm.write {
                for transaction in unprocessedTransactions {
                    try extractor.extract(transaction: transaction)
                    linker.handle(transaction: transaction, realm: realm)
                    transaction.processed = true
                }
            }

            try addressManager.generateKeys()
        }
    }

}
