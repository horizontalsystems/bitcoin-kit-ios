import RxSwift

class TransactionProcessor {
    private let storage: IStorage
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let outputsCache: IOutputsCache
    private let publicKeyManager: IPublicKeyManager
    private let irregularOutputFinder: IIrregularOutputFinder
    private let transactionInfoConverter: ITransactionInfoConverter

    weak var listener: IBlockchainDataListener?
    weak var transactionListener: ITransactionListener?

    private let dateGenerator: () -> Date
    private let queue: DispatchQueue

    init(storage: IStorage, outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, outputsCache: IOutputsCache,
         outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IPublicKeyManager, irregularOutputFinder: IIrregularOutputFinder, transactionInfoConverter: ITransactionInfoConverter,
         listener: IBlockchainDataListener? = nil, dateGenerator: @escaping () -> Date = Date.init, queue: DispatchQueue = DispatchQueue(label: "Transactions", qos: .background
    )) {
        self.storage = storage
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.outputsCache = outputsCache
        self.publicKeyManager = addressManager
        self.irregularOutputFinder = irregularOutputFinder
        self.transactionInfoConverter = transactionInfoConverter
        self.listener = listener
        self.dateGenerator = dateGenerator
        self.queue = queue
    }

    private func process(transaction: FullTransaction) {
        outputExtractor.extract(transaction: transaction)
        if outputsCache.hasOutputs(forInputs: transaction.inputs) {
            transaction.header.isMine = true
            transaction.header.isOutgoing = true
        }

        guard transaction.header.isMine else {
            return
        }
        outputsCache.add(fromOutputs: transaction.outputs)
        outputAddressExtractor.extractOutputAddresses(transaction: transaction)
        inputExtractor.extract(transaction: transaction)
    }

    private func relay(transaction: Transaction, withOrder order: Int, inBlock block: Block?) {
        transaction.blockHash = block?.headerHash
        transaction.status = .relayed
        transaction.timestamp = block?.timestamp ?? Int(dateGenerator().timeIntervalSince1970)
        transaction.order = order

        if let block = block, !block.hasTransactions {
            block.hasTransactions = true
            storage.update(block: block)
        }
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func processReceived(transactions: [FullTransaction], inBlock block: Block?, skipCheckBloomFilter: Bool) throws {
        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()

        try queue.sync {
            for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
                if let existingTransaction = self.storage.transaction(byHash: transaction.header.dataHash) {
                    if existingTransaction.blockHash != nil && block == nil {
                        continue
                    }
                    self.relay(transaction: existingTransaction, withOrder: index, inBlock: block)
                    try self.storage.update(transaction: existingTransaction)
                    updated.append(existingTransaction)
                    continue
                }

                self.process(transaction: transaction)
                self.transactionListener?.onReceive(transaction: transaction)

                if transaction.header.isMine {
                    self.relay(transaction: transaction.header, withOrder: index, inBlock: block)
                    try self.storage.add(transaction: transaction)

                    inserted.append(transaction.header)

                    if !skipCheckBloomFilter {
                        needToUpdateBloomFilter = needToUpdateBloomFilter || self.publicKeyManager.gapShifts() || self.irregularOutputFinder.hasIrregularOutput(outputs: transaction.outputs)
                    }
                }
            }
        }

        if !updated.isEmpty || !inserted.isEmpty {
            listener?.onUpdate(updated: updated, inserted: inserted, inBlock: block)
        }

        if needToUpdateBloomFilter {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

    func processCreated(transaction: FullTransaction) throws {
        guard storage.transaction(byHash: transaction.header.dataHash) == nil else {
            throw TransactionCreator.CreationError.transactionAlreadyExists
        }

        process(transaction: transaction)
        try storage.add(transaction: transaction)
        listener?.onUpdate(updated: [], inserted: [transaction.header], inBlock: nil)

        if irregularOutputFinder.hasIrregularOutput(outputs: transaction.outputs) {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

    public func processInvalid(transactionHash: Data) {
        guard let fullTransactionInfo = storage.fullTransactionInfo(byHash: transactionHash) else {
            return
        }

        let transaction = fullTransactionInfo.transactionWithBlock.transaction
        transaction.status = .invalid

        let transactionInfo = transactionInfoConverter.transactionInfo(fromTransaction: fullTransactionInfo)

        try? storage.invalidate(transaction: transaction, transactionInfo: transactionInfo)
        listener?.onUpdate(updated: [transaction], inserted: [], inBlock: nil)
    }
}
