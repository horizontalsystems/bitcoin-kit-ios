open class TransactionInfoConverter: ITransactionInfoConverter {
    private let baseTransactionInfoConverter: IBaseTransactionInfoConverter

    public init(baseTransactionInfoConverter: IBaseTransactionInfoConverter) {
        self.baseTransactionInfoConverter = baseTransactionInfoConverter
    }

    public func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo {
        return baseTransactionInfoConverter.transactionInfo(fromTransaction: transactionForInfo)
    }

}
