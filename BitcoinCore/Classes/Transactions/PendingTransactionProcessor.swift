import RxSwift

class PendingTransactionProcessor {
    private let storage: IStorage
    private let extractor: ITransactionExtractor
    private let publicKeyManager: IPublicKeyManager
    private let irregularOutputFinder: IIrregularOutputFinder
    private let conflictsResolver: ITransactionConflictsResolver

    weak var listener: IBlockchainDataListener?
    weak var transactionListener: ITransactionListener?

    private let queue: DispatchQueue

    private var notMineTransactions = Set<Data>()

    init(storage: IStorage, extractor: ITransactionExtractor, publicKeyManager: IPublicKeyManager, irregularOutputFinder: IIrregularOutputFinder, conflictsResolver: ITransactionConflictsResolver,
         listener: IBlockchainDataListener? = nil, queue: DispatchQueue) {
        self.storage = storage
        self.extractor = extractor
        self.publicKeyManager = publicKeyManager
        self.irregularOutputFinder = irregularOutputFinder
        self.conflictsResolver = conflictsResolver
        self.listener = listener
        self.queue = queue
    }

    private func relay(transaction: Transaction, order: Int) {
        transaction.status = .relayed
        transaction.order = order
    }

}

extension PendingTransactionProcessor: IPendingTransactionProcessor {

    func processReceived(transactions: [FullTransaction], skipCheckBloomFilter: Bool) throws {
        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()

        try queue.sync {
            for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
                if notMineTransactions.contains(transaction.header.dataHash) {
                    // already processed this transaction with same state
                    continue
                }

                let invalidTransaction = storage.invalidTransaction(byHash: transaction.header.dataHash)
                if invalidTransaction != nil {
                    // if some peer send us transaction after it's invalidated, we must ignore it
                    continue
                }

                if let existingTransaction = storage.transaction(byHash: transaction.header.dataHash) {
                    if existingTransaction.status == .relayed {
                        // if comes again from memPool we don't need to update it
                        continue
                    }

                    relay(transaction: existingTransaction, order: index)

                    try storage.update(transaction: existingTransaction)
                    updated.append(existingTransaction)

                    continue
                }

                relay(transaction: transaction.header, order: index)
                extractor.extract(transaction: transaction)
                transactionListener?.onReceive(transaction: transaction)

                guard transaction.header.isMine else {
                    notMineTransactions.insert(transaction.header.dataHash)

                    for tx in conflictsResolver.incomingPendingTransactionsConflicting(with: transaction) {
                        // Former incoming transaction is conflicting with current transaction
                        tx.conflictingTxHash = transaction.header.dataHash
                        try storage.update(transaction: tx)
                        updated.append(tx)
                    }

                    continue
                }

                let conflictingTransactions = conflictsResolver.transactionsConflicting(withPendingTransaction: transaction)
                if !conflictingTransactions.isEmpty {
                    // Ignore current transaction and mark former transactions as conflicting with current transaction
                    for tx in conflictingTransactions {
                        tx.conflictingTxHash = transaction.header.dataHash
                        try storage.update(transaction: tx)
                        updated.append(tx)
                    }
                } else {
                    try storage.add(transaction: transaction)
                    inserted.append(transaction.header)
                }

                let needToCheckDoubleSpend = !transaction.header.isOutgoing
                if !skipCheckBloomFilter {
                    needToUpdateBloomFilter = needToUpdateBloomFilter ||
                            needToCheckDoubleSpend ||
                            publicKeyManager.gapShifts() ||
                            irregularOutputFinder.hasIrregularOutput(outputs: transaction.outputs)
                }
            }
        }

        if !updated.isEmpty || !inserted.isEmpty {
            listener?.onUpdate(updated: updated, inserted: inserted, inBlock: nil)
        }

        if needToUpdateBloomFilter {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

    func processCreated(transaction: FullTransaction) throws {
        guard storage.transaction(byHash: transaction.header.dataHash) == nil else {
            throw TransactionCreator.CreationError.transactionAlreadyExists
        }

        extractor.extract(transaction: transaction)
        try storage.add(transaction: transaction)
        listener?.onUpdate(updated: [], inserted: [transaction.header], inBlock: nil)

        if irregularOutputFinder.hasIrregularOutput(outputs: transaction.outputs) {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

}
