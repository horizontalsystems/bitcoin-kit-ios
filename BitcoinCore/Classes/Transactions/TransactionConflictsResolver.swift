class TransactionConflictsResolver {
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    private func conflictingTransactions(for transaction: FullTransaction) -> [Transaction] {
        let storageTransactionHashes = transaction.inputs.compactMap { input in
            storage.inputsUsing(previousOutputTxHash: input.previousOutputTxHash, previousOutputIndex: input.previousOutputIndex)
                    .filter {
                $0.transactionHash != transaction.header.dataHash
            }.first?.transactionHash
        }
        guard !storageTransactionHashes.isEmpty else {
            return []
        }

        return Array(Set(storageTransactionHashes)).compactMap {
            storage.transaction(byHash: $0)
        }
    }

}

extension TransactionConflictsResolver: ITransactionConflictsResolver {

    // Only pending transactions may be conflicting with a transaction in block. No need to check that
    func transactionsConflicting(withInblockTransaction transaction: FullTransaction) -> [Transaction] {
        self.conflictingTransactions(for: transaction)
    }

    func transactionsConflicting(withPendingTransaction transaction: FullTransaction) -> [Transaction] {
        let conflictingTransactions = self.conflictingTransactions(for: transaction)

        guard !conflictingTransactions.isEmpty else {
            return []
        }

        // If any of conflicting transactions is already in a block, then current transaction is invalid and non of them is conflicting with it.
        guard conflictingTransactions.allSatisfy({ $0.blockHash == nil }) else {
            return []
        }

        return conflictingTransactions
    }

    func incomingPendingTransactionsConflicting(with transaction: FullTransaction) -> [Transaction] {
        let pendingTxHashes = storage.incomingPendingTransactionHashes()
        if pendingTxHashes.isEmpty {
            return []
        }

        let conflictingTransactionHashes = storage
                .inputs(byHashes: pendingTxHashes)
                .filter { input in
                    transaction.inputs.contains { $0.previousOutputIndex == input.previousOutputIndex && $0.previousOutputTxHash == input.previousOutputTxHash }
                }
                .map { $0.transactionHash }
        if conflictingTransactionHashes.isEmpty {                                               // handle if transaction has conflicting inputs, otherwise it's false-positive tx
            return []
        }

        return Array(Set(conflictingTransactionHashes))                                         // make unique elements
                .compactMap { storage.transaction(byHash: $0) }                                 // get transactions for each input
                .filter { $0.blockHash == nil }                                                 // exclude all transactions in blocks
    }

}
