import Foundation

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

    func pendingTransactions() -> [FullTransaction] {
        return storage.newTransactions()
                .filter { transaction in
                    if let sentTransaction = storage.sentTransaction(byHash: transaction.dataHash) {
                        return sentTransaction.retriesCount < self.maxRetriesCount &&
                                sentTransaction.lastSendTime < CACurrentMediaTime() - self.retriesPeriod &&
                                sentTransaction.firstSendTime > CACurrentMediaTime() - self.totalRetriesPeriod
                    } else {
                        return true
                    }
                }
                .map { FullTransaction(header: $0, inputs: self.storage.inputs(ofTransaction: $0), outputs: self.storage.outputs(ofTransaction: $0)) }
    }

    func handle(sentTransaction transaction: FullTransaction) {
        guard let transaction = storage.newTransaction(byHash: transaction.header.dataHash) else {
            return
        }

        if let sentTransaction = storage.sentTransaction(byHash: transaction.dataHash) {
            sentTransaction.lastSendTime = CACurrentMediaTime()
            sentTransaction.retriesCount = sentTransaction.retriesCount + 1
            storage.update(sentTransaction: sentTransaction)
        } else {
            storage.add(sentTransaction: SentTransaction(dataHash: transaction.dataHash))
        }
    }

    func handle(transactions: [FullTransaction]) {
        guard !transactions.isEmpty else {
            return
        }

        var needToUpdateBloomFilter = false

        do {
            try self.transactionProcessor.processReceived(transactions: transactions, inBlock: nil, skipCheckBloomFilter: false)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            needToUpdateBloomFilter = true
        } catch {
        }

        if needToUpdateBloomFilter {
            try? addressManager.fillGap()
            bloomFilterManager.regenerateBloomFilter()
        }
    }

    func shouldRequestTransaction(hash: Data) -> Bool {
        return !storage.relayedTransactionExists(byHash: hash)
    }

}
