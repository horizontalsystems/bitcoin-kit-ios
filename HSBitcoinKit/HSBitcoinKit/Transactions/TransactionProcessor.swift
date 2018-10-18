import RealmSwift
import RxSwift

class TransactionProcessor {
    private let realmFactory: IRealmFactory
    private let extractor: ITransactionExtractor
    private let linker: ITransactionLinker
    private let addressManager: IAddressManager
    private let queue: DispatchQueue

    init(realmFactory: IRealmFactory, extractor: ITransactionExtractor, linker: ITransactionLinker, addressManager: IAddressManager, queue: DispatchQueue = DispatchQueue(label: "TransactionWorker", qos: .background)) {
        self.realmFactory = realmFactory
        self.extractor = extractor
        self.linker = linker
        self.addressManager = addressManager
        self.queue = queue
    }

    private func run() throws {
        let realm = realmFactory.realm

        let unprocessedTransactions = realm.objects(Transaction.self).filter("processed = %@", false)

        if !unprocessedTransactions.isEmpty {
            try realm.write {
                for transaction in unprocessedTransactions {
                    process(transaction: transaction, realm: realm)
                }
            }

            try addressManager.fillGap()
        }
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func enqueueRun() {
        queue.async {
            do {
                try self.run()
            } catch {
                Logger.shared.log(self, "\(error)")
            }
        }
    }

    func process(transaction: Transaction, realm: Realm) {
        extractor.extract(transaction: transaction, realm: realm)
        linker.handle(transaction: transaction, realm: realm)
        transaction.processed = true
    }

}
