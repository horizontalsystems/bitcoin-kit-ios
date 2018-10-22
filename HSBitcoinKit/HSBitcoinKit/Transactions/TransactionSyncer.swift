class TransactionSyncer {
    private let realmFactory: IRealmFactory
    private let processor: ITransactionProcessor
    private let queue: DispatchQueue

    init(realmFactory: IRealmFactory, processor: ITransactionProcessor, queue: DispatchQueue = DispatchQueue(label: "TransactionSyncer", qos: .userInitiated)) {
        self.realmFactory = realmFactory
        self.processor = processor
        self.queue = queue
    }

    private func _handle(transactions: [Transaction]) throws {
        guard !transactions.isEmpty else {
            return
        }

        let realm = realmFactory.realm

        try realm.write {
            for transaction in transactions {
                if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                    existingTransaction.status = .relayed
                } else {
                    processor.process(transaction: transaction, realm: realm)
                    if transaction.isMine {
                        realm.add(transaction)
                    }
                }
            }
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
