import Foundation
import RealmSwift

class TransactionSyncer {
    private let storage: IStorage
    private let transactionProcessor: ITransactionProcessor
    private let addressManager: IAddressManager
    private let bloomFilterManager: IBloomFilterManager
    private let maxRetriesCount: Int
    private let retriesPeriod: Double // seconds
    private let totalRetriesPeriod: Double // seconds

    init(storage: IStorage, processor: ITransactionProcessor, addressManager: IAddressManager, bloomFilterManager: IBloomFilterManager,
         maxRetriesCount: Int = 3, retriesPeriod: Double = 60, totalRetriesPeriod: Double = 60 * 60 * 24) {
        self.storage = storage
        self.transactionProcessor = processor
        self.addressManager = addressManager
        self.bloomFilterManager = bloomFilterManager
        self.maxRetriesCount = maxRetriesCount
        self.retriesPeriod = retriesPeriod
        self.totalRetriesPeriod = totalRetriesPeriod
    }

}

extension TransactionSyncer: ITransactionSyncer {

    func pendingTransactions() -> [Transaction] {
        let pendingTransactions = storage.newTransactions().filter { transaction in
            if let sentTransaction = storage.sentTransaction(byReversedHashHex: transaction.reversedHashHex) {
                return sentTransaction.retriesCount < self.maxRetriesCount &&
                        sentTransaction.lastSendTime < CACurrentMediaTime() - self.retriesPeriod &&
                        sentTransaction.firstSendTime > CACurrentMediaTime() - self.totalRetriesPeriod
            } else {
                return true
            }
        }

        return Array(pendingTransactions)
    }

    func handle(sentTransaction transaction: Transaction) {
        guard let transaction = storage.newTransaction(byReversedHashHex: transaction.reversedHashHex) else {
            return
        }

        if let sentTransaction = storage.sentTransaction(byReversedHashHex: transaction.reversedHashHex) {
            sentTransaction.lastSendTime = CACurrentMediaTime()
            sentTransaction.retriesCount = sentTransaction.retriesCount + 1
            storage.update(sentTransaction: sentTransaction)
        } else {
            storage.add(sentTransaction: SentTransaction(reversedHashHex: transaction.reversedHashHex))
        }
    }

    func handle(transactions: [Transaction]) {
        guard !transactions.isEmpty else {
            return
        }

        var needToUpdateBloomFilter = false

        try? storage.inTransaction { realm in
            do {
                try self.transactionProcessor.process(transactions: transactions, inBlock: nil, skipCheckBloomFilter: false, realm: realm)
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
        return !storage.relayedTransactionExists(byReversedHashHex: hash.reversedHex)
    }

}
