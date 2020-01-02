class TransactionMediator: ITransactionMediator {

    func resolve(receivedTransaction transaction: FullTransaction, conflictingTransactions: [Transaction]) -> ConflictResolution {
        guard !conflictingTransactions.isEmpty else {
            return .accept
        }
        guard transaction.header.blockHash == nil else {
            conflictingTransactions.forEach {
                $0.conflictingTxHash = transaction.header.dataHash
            }
            return .accept
        }

        let conflictingHash = conflictingTransactions.allSatisfy { $0.blockHash == nil } ? transaction.header.dataHash : nil

        conflictingTransactions.forEach {
            $0.conflictingTxHash = conflictingHash
        }
        return .ignore
    }

}
