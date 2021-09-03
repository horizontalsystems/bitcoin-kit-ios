import RxSwift

class TransactionExtractor {
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionExtractor
    private let metaDataExtractor: ITransactionExtractor

    init(outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, metaDataExtractor: ITransactionExtractor, outputAddressExtractor: ITransactionExtractor) {
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.metaDataExtractor = metaDataExtractor
    }

}

extension TransactionExtractor: ITransactionExtractor {

    func extract(transaction: FullTransaction) {
        outputExtractor.extract(transaction: transaction)
        metaDataExtractor.extract(transaction: transaction)

        if transaction.header.isMine {
            outputAddressExtractor.extract(transaction: transaction)
            inputExtractor.extract(transaction: transaction)
        }
    }

}
