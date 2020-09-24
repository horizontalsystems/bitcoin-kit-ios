import RxSwift

class BlockTransactionProcessor {
    private let storage: IStorage
    private let extrator: ITransactionExtractor
    private let publicKeyManager: IPublicKeyManager
    private let irregularOutputFinder: IIrregularOutputFinder
    private let conflictsResolver: TransactionConflictsResolver
    private let invalidator: TransactionInvalidator

    weak var listener: IBlockchainDataListener?
    weak var transactionListener: ITransactionListener?

    private let queue: DispatchQueue

    init(storage: IStorage, extractor: ITransactionExtractor, publicKeyManager: IPublicKeyManager, irregularOutputFinder: IIrregularOutputFinder,
         conflictsResolver: TransactionConflictsResolver, invalidator: TransactionInvalidator, listener: IBlockchainDataListener? = nil, queue: DispatchQueue) {
        self.storage = storage
        self.extrator = extractor
        self.publicKeyManager = publicKeyManager
        self.irregularOutputFinder = irregularOutputFinder
        self.conflictsResolver = conflictsResolver
        self.invalidator = invalidator
        self.listener = listener
        self.queue = queue
    }

    private func relay(transaction: Transaction, inBlock block: Block, order: Int) {
        transaction.blockHash = block.headerHash
        transaction.timestamp = block.timestamp
        transaction.conflictingTxHash = nil
        transaction.status = .relayed
        transaction.order = order
    }

}

extension BlockTransactionProcessor: IBlockTransactionProcessor {

    func processReceived(transactions: [FullTransaction], inBlock block: Block, skipCheckBloomFilter: Bool) throws {
        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()

        try queue.sync {
            for (index, fullTransaction) in transactions.inTopologicalOrder().enumerated() {
                let transaction = fullTransaction.header
                if let existingTransaction = storage.fullTransaction(byHash: fullTransaction.header.dataHash) {
                    extrator.extract(transaction: existingTransaction)
                    transactionListener?.onReceive(transaction: existingTransaction)
                    relay(transaction: existingTransaction.header, inBlock: block, order: index)

                    try storage.update(transaction: existingTransaction)
                    updated.append(existingTransaction.header)

                    continue
                }

                extrator.extract(transaction: fullTransaction)
                transactionListener?.onReceive(transaction: fullTransaction)

                guard transaction.isMine else {
                    for tx in conflictsResolver.incomingPendingTransactionsConflicting(with: fullTransaction) {
                        tx.conflictingTxHash = fullTransaction.header.dataHash
                        invalidator.invalidate(transaction: tx)
                        needToUpdateBloomFilter = true
                    }

                    continue
                }

                relay(transaction: transaction, inBlock: block, order: index)

                conflictsResolver.transactionsConflicting(withInblockTransaction: fullTransaction).forEach {
                    $0.conflictingTxHash = fullTransaction.header.dataHash
                    invalidator.invalidate(transaction: $0)
                }

                if let invalidTransaction = storage.invalidTransaction(byHash: transaction.dataHash) {
                    try storage.move(invalidTransaction: invalidTransaction, toTransactions: fullTransaction)
                    updated.append(transaction)
                } else {
                    try storage.add(transaction: fullTransaction)
                    inserted.append(fullTransaction.header)
                }

                if !skipCheckBloomFilter {
                    needToUpdateBloomFilter = needToUpdateBloomFilter ||
                            publicKeyManager.gapShifts() ||
                            irregularOutputFinder.hasIrregularOutput(outputs: fullTransaction.outputs)
                }
            }
        }

        if !updated.isEmpty || !inserted.isEmpty {
            if !block.hasTransactions {
                block.hasTransactions = true
                storage.update(block: block)
            }

            listener?.onUpdate(updated: updated, inserted: inserted, inBlock: block)
        }

        if needToUpdateBloomFilter {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }
}
