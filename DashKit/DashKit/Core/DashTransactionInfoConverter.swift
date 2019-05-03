import BitcoinCore

public class DashTransactionInfoConverter: ITransactionInfoConverter {
    private let baseTransactionInfoConverter: IBaseTransactionInfoConverter

    public init(baseTransactionInfoConverter: IBaseTransactionInfoConverter) {
        self.baseTransactionInfoConverter = baseTransactionInfoConverter
    }


    public func transactionInfo(fromTransaction transactionForInfo: FullTransactionForInfo) -> TransactionInfo {
        let txInfo: DashTransactionInfo = baseTransactionInfoConverter.transactionInfo(fromTransaction: transactionForInfo)

        return txInfo
    }

}
