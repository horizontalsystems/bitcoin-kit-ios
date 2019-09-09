import Foundation

public class TransactionSyncer {
    private let storage: IStorage
    private let transactionProcessor: ITransactionProcessor
    private let publicKeyManager: IPublicKeyManager
    private let maxRetriesCount: Int
    private let retriesPeriod: Double // seconds
    private let totalRetriesPeriod: Double // seconds

    init(storage: IStorage, processor: ITransactionProcessor, publicKeyManager: IPublicKeyManager,
         maxRetriesCount: Int = 3, retriesPeriod: Double = 60, totalRetriesPeriod: Double = 60 * 60 * 24) {
        self.storage = storage
        self.transactionProcessor = processor
        self.publicKeyManager = publicKeyManager
        self.maxRetriesCount = maxRetriesCount
        self.retriesPeriod = retriesPeriod
        self.totalRetriesPeriod = totalRetriesPeriod
    }

}

extension TransactionSyncer: ITransactionSyncer {

    public func pendingTransactions() -> [FullTransaction] {
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
                .map { FullTransaction(header: $0, inputs: self.storage.inputs(transactionHash: $0.dataHash), outputs: self.storage.outputs(transactionHash: $0.dataHash)) }
    }

    public func handle(sentTransaction transaction: FullTransaction) {
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

    public func handle(transactions: [FullTransaction]) {
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
            try? publicKeyManager.fillGap()
        }
    }

    public func shouldRequestTransaction(hash: Data) -> Bool {
        return !storage.relayedTransactionExists(byHash: hash)
    }

}
