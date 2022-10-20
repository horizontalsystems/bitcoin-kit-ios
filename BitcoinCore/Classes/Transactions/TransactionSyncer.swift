import Foundation

public class TransactionSyncer {
    private let storage: IStorage
    private let processor: IPendingTransactionProcessor
    private let invalidator: TransactionInvalidator
    private let publicKeyManager: IPublicKeyManager

    init(storage: IStorage, processor: IPendingTransactionProcessor, invalidator: TransactionInvalidator, publicKeyManager: IPublicKeyManager) {
        self.storage = storage
        self.processor = processor
        self.invalidator = invalidator
        self.publicKeyManager = publicKeyManager
    }

}

extension TransactionSyncer: ITransactionSyncer {

    public func newTransactions() -> [FullTransaction] {
        storage.newTransactions()
    }

    public func handleRelayed(transactions: [FullTransaction]) {
        guard !transactions.isEmpty else {
            return
        }

        var needToUpdateBloomFilter = false

        do {
            try self.processor.processReceived(transactions: transactions, skipCheckBloomFilter: false)
        } catch _ as BloomFilterManager.BloomFilterExpired {
            needToUpdateBloomFilter = true
        } catch {
        }

        if needToUpdateBloomFilter {
            try? publicKeyManager.fillGap()
        }
    }

    public func handleInvalid(fullTransaction: FullTransaction) {
        invalidator.invalidate(transaction: fullTransaction.header)
    }

    public func shouldRequestTransaction(hash: Data) -> Bool {
        !storage.relayedTransactionExists(byHash: hash)
    }

}
