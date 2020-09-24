import RxSwift

class TransactionExtractor {
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let outputsCache: IOutputsCache

    init(outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, outputsCache: IOutputsCache, outputAddressExtractor: ITransactionOutputAddressExtractor) {
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.outputsCache = outputsCache
    }

}

extension TransactionExtractor: ITransactionExtractor {

    func extract(transaction: FullTransaction) {
        outputExtractor.extract(transaction: transaction)
        if outputsCache.hasOutputs(forInputs: transaction.inputs) {
            transaction.header.isMine = true
            transaction.header.isOutgoing = true
        }

        guard transaction.header.isMine else {
            return
        }
        outputsCache.addMineOutputs(from: transaction.outputs)
        outputAddressExtractor.extractOutputAddresses(transaction: transaction)
        inputExtractor.extract(transaction: transaction)
    }

}
