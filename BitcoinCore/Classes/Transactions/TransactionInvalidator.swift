class TransactionInvalidator {
    private let storage: IStorage
    private let transactionInfoConverter: ITransactionInfoConverter

    weak var listener: IBlockchainDataListener?

    init(storage: IStorage, transactionInfoConverter: ITransactionInfoConverter, listener: IBlockchainDataListener? = nil) {
        self.storage = storage
        self.transactionInfoConverter = transactionInfoConverter
        self.listener = listener
    }

    private func descendantTransactionsFullInfo(of transactionHash: Data) -> [FullTransactionForInfo] {
        guard let fullTransactionInfo = storage.transactionFullInfo(byHash: transactionHash) else {
            return []
        }

        return storage
                .inputsUsingOutputs(withTransactionHash: transactionHash)
                .reduce(into: [fullTransactionInfo]) { list, input in
                    list.append(contentsOf: descendantTransactionsFullInfo(of: input.transactionHash))
                }
    }

}

extension TransactionInvalidator: ITransactionInvalidator {

    public func invalidate(transaction: Transaction) {
        let invalidTransactionsFullInfo = descendantTransactionsFullInfo(of: transaction.dataHash)

        guard !invalidTransactionsFullInfo.isEmpty else {
            return
        }

        invalidTransactionsFullInfo.forEach {
            $0.transactionWithBlock.transaction.status = .invalid
        }

        let invalidTransactions: [InvalidTransaction] = invalidTransactionsFullInfo.map { transactionFullInfo in
            let transactionInfo = transactionInfoConverter.transactionInfo(fromTransaction: transactionFullInfo)
            var transactionInfoJson = Data()
            if let jsonData = try? JSONEncoder.init().encode(transactionInfo) {
                transactionInfoJson = jsonData
            }

            let transaction = transactionFullInfo.transactionWithBlock.transaction
            return InvalidTransaction(
                    uid: transaction.uid, dataHash: transaction.dataHash, version: transaction.version, lockTime: transaction.lockTime, timestamp: transaction.timestamp,
                    order: transaction.order, blockHash: transaction.blockHash, isMine: transaction.isMine, isOutgoing: transaction.isOutgoing,
                    status: transaction.status, segWit: transaction.segWit, conflictingTxHash: transaction.conflictingTxHash,
                    transactionInfoJson: transactionInfoJson, rawTransaction: transactionFullInfo.rawTransaction
            )
        }


        try? storage.moveTransactionsTo(invalidTransactions: invalidTransactions)
        listener?.onUpdate(updated: invalidTransactions, inserted: [], inBlock: nil)
    }

}
