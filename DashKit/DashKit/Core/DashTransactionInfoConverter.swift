import BitcoinCore

class DashTransactionInfoConverter: ITransactionInfoConverter {
    private let baseTransactionInfoConverter: IBaseTransactionInfoConverter
    private let instantTransactionManager: IInstantTransactionManager

    init(baseTransactionInfoConverter: IBaseTransactionInfoConverter, instantTransactionManager: IInstantTransactionManager) {
        self.baseTransactionInfoConverter = baseTransactionInfoConverter
        self.instantTransactionManager = instantTransactionManager
    }


    func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo {
        let txInfo: DashTransactionInfo = baseTransactionInfoConverter.transactionInfo(fromTransaction: transactionForInfo)
        txInfo.instantTx = instantTransactionManager.isTransactionInstant(txHash: transactionForInfo.transactionWithBlock.transaction.dataHash)
        return txInfo
    }

}
