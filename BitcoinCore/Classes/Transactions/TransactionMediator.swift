class TransactionMediator: ITransactionMediator {

    func resolve(receivedTransaction transaction: FullTransaction, conflictingTransactions: [Transaction], updatingTransactions: inout [Transaction]) -> ConflictResolution {
        guard !conflictingTransactions.isEmpty else {
            return .accept
        }
        guard transaction.header.blockHash == nil else {
            updatingTransactions.append(contentsOf: conflictingTransactions)
            return .accept
        }

        let conflictingHash = conflictingTransactions.allSatisfy { $0.blockHash == nil } ? transaction.header.dataHash : nil

        conflictingTransactions.forEach {
            if $0.conflictingTxHash == nil && conflictingHash != nil {
                $0.conflictingTxHash = conflictingHash
                updatingTransactions.append($0)
            }
        }
        return .ignore
    }

}
