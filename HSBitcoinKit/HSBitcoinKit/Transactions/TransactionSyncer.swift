import Foundation
import RealmSwift

class TransactionSyncer {
    private let realmFactory: IRealmFactory
    private let transactionProcessor: ITransactionProcessor
    private let addressManager: IAddressManager
    private let bloomFilterManager: IBloomFilterManager

    init(realmFactory: IRealmFactory, processor: ITransactionProcessor, addressManager: IAddressManager, bloomFilterManager: IBloomFilterManager) {
        self.realmFactory = realmFactory
        self.transactionProcessor = processor
        self.addressManager = addressManager
        self.bloomFilterManager = bloomFilterManager
    }

}

extension TransactionSyncer: ITransactionSyncer {

    func getNonSentTransactions() -> [Transaction] {
        let realm = realmFactory.realm
        let nonSentTransactions = realm.objects(Transaction.self).filter("status = %@", TransactionStatus.new.rawValue)
        return Array(nonSentTransactions)
    }

    func handle(transactions: [Transaction]) {
        guard !transactions.isEmpty else {
            return
        }

        let realm = realmFactory.realm
        var needToUpdateBloomFilter = false

        try? realm.write {
            do {
                try self.transactionProcessor.process(transactions: transactions, inBlock: nil, checkBloomFilter: true, realm: realm)
            } catch _ as BloomFilterManager.BloomFilterExpired {
                needToUpdateBloomFilter = true
            }
        }

        if needToUpdateBloomFilter {
            try? addressManager.fillGap()
            bloomFilterManager.regenerateBloomFilter()
        }
    }

    func shouldRequestTransaction(hash: Data) -> Bool {
        let realm = realmFactory.realm
        return realm.objects(Transaction.self).filter("reversedHashHex = %@", hash.reversedHex).isEmpty
    }

}
