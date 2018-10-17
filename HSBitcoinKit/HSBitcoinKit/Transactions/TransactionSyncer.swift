import Foundation

class TransactionSyncer {

    private let realmFactory: RealmFactory
    private let processor: TransactionProcessor
    private let queue: DispatchQueue

    init(realmFactory: RealmFactory, processor: TransactionProcessor, queue: DispatchQueue = DispatchQueue(label: "TransactionSyncer", qos: .userInitiated)) {
        self.realmFactory = realmFactory
        self.processor = processor
        self.queue = queue
    }

    private func _handle(transactions: [Transaction]) throws {
        guard !transactions.isEmpty else {
            return
        }

        let realm = realmFactory.realm

        var hasNewTransactions = false

        try realm.write {
            for transaction in transactions {
                if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                    existingTransaction.status = .relayed
                } else {
                    realm.add(transaction)
                    hasNewTransactions = true
                }
            }
        }

        if hasNewTransactions {
            processor.enqueueRun()
        }
    }

}

extension TransactionSyncer: ITransactionSyncer {

    func getNonSentTransactions() -> [Transaction] {
        let realm = realmFactory.realm
        let nonSentTransactions = realm.objects(Transaction.self).filter("status = %@", TransactionStatus.new.rawValue)
        return Array(nonSentTransactions)
    }

    func handle(transactions: [Transaction]) {
        queue.async {
            do {
                try self._handle(transactions: transactions)
            } catch {
                Logger.shared.log(self, "Handle Error: \(error)")
            }
        }
    }

    func shouldRequestTransaction(hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Transaction.self).filter("reversedHashHex = %@", hash.reversedHex).isEmpty
    }

}

protocol ITransactionSyncer: class {

    func getNonSentTransactions() -> [Transaction]
    func handle(transactions: [Transaction])
    func shouldRequestTransaction(hash: Data) -> Bool

}
