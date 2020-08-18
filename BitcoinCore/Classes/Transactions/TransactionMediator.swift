class TransactionMediator: ITransactionMediator {

    func resolve(receivedTransaction transaction: FullTransaction, conflictingTransactions: [Transaction]) -> ConflictResolution {
        if transaction.header.blockHash != nil || conflictingTransactions.isEmpty {
            return .accept(needToMakeInvalid: conflictingTransactions)
        }

        let conflictingHash = conflictingTransactions.allSatisfy { $0.blockHash == nil } ? transaction.header.dataHash : nil
        var updatingTransactions = [Transaction]()

        conflictingTransactions.forEach {
            if $0.conflictingTxHash == nil && conflictingHash != nil {
                $0.conflictingTxHash = conflictingHash
                updatingTransactions.append($0)
            }
        }
        return .ignore(needToUpdate: updatingTransactions)
    }

}
