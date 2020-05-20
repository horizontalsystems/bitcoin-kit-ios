import RxSwift

private struct NotMineTransaction: Hashable {
    let hash: Data
    let inBlock: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
        hasher.combine(inBlock)
    }

    static func ==(lhs: NotMineTransaction, rhs: NotMineTransaction) -> Bool {
         lhs.hash == rhs.hash && lhs.inBlock == rhs.inBlock
    }
}

class TransactionProcessor {
    private let storage: IStorage
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let outputsCache: IOutputsCache
    private let publicKeyManager: IPublicKeyManager
    private let irregularOutputFinder: IIrregularOutputFinder
    private let transactionInfoConverter: ITransactionInfoConverter
    private let transactionMediator: ITransactionMediator

    weak var listener: IBlockchainDataListener?
    weak var transactionListener: ITransactionListener?

    private let dateGenerator: () -> Date
    private let queue: DispatchQueue

    private var notMineTransactions = Set<NotMineTransaction>()

    init(storage: IStorage, outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, outputsCache: IOutputsCache,
         outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IPublicKeyManager, irregularOutputFinder: IIrregularOutputFinder,
         transactionInfoConverter: ITransactionInfoConverter, transactionMediator: ITransactionMediator,
         listener: IBlockchainDataListener? = nil, dateGenerator: @escaping () -> Date = Date.init, queue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.transaction-processor", qos: .background
    )) {
        self.storage = storage
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.outputsCache = outputsCache
        self.publicKeyManager = addressManager
        self.irregularOutputFinder = irregularOutputFinder
        self.transactionInfoConverter = transactionInfoConverter
        self.transactionMediator = transactionMediator
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
        if let block = block  {
            transaction.timestamp = block.timestamp
        }
        transaction.status = .relayed
        transaction.order = order

        if let block = block, !block.hasTransactions {
            block.hasTransactions = true
            storage.update(block: block)
        }
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func processReceived(transactions: [FullTransaction], inBlock block: Block?, skipCheckBloomFilter: Bool) throws {
        let inBlock = block != nil
        let existPending = !inBlock || storage.incomingPendingTransactionsExist()

        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()

        try queue.sync {
            for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
                let probablyNotMineTransaction = NotMineTransaction(hash: transaction.header.dataHash, inBlock: inBlock)
                if notMineTransactions.contains(probablyNotMineTransaction) {                                                // already processed this transaction with same state
                    continue
                }

                if storage.invalidTransaction(byHash: transaction.header.dataHash) != nil {                                  // if some peer send us transaction after it's invalidated, we must ignore it
                    continue
                }
                if let existingTransaction = self.storage.transaction(byHash: transaction.header.dataHash) {
                    if existingTransaction.blockHash != nil || (existingTransaction.status == .relayed && !inBlock) {       // if transaction already in block or transaction comes again from memPool we don't need update it
                        continue
                    }
                    self.relay(transaction: existingTransaction, withOrder: index, inBlock: block)

                    if inBlock {
                        existingTransaction.conflictingTxHash = nil
                    }
                    try self.storage.update(transaction: existingTransaction)
                    updated.append(existingTransaction)

                    continue
                }

                self.process(transaction: transaction)
                self.transactionListener?.onReceive(transaction: transaction)

                if transaction.header.isMine {
                    self.relay(transaction: transaction.header, withOrder: index, inBlock: block)

                    let conflictingTransactions = storage.conflictingTransactions(for: transaction)

                    var needToUpdate = [Transaction]()
                    let resolution = transactionMediator.resolve(receivedTransaction: transaction, conflictingTransactions: conflictingTransactions, updatingTransactions: &needToUpdate)
                    switch resolution {
                    case .ignore:
                        try needToUpdate.forEach {
                            try storage.update(transaction: $0)
                        }
                        updated.append(contentsOf: needToUpdate)

                    case .accept:
                        needToUpdate.forEach {
                            processInvalid(transactionHash: $0.dataHash, conflictingTxHash: transaction.header.dataHash)
                        }

                        try self.storage.add(transaction: transaction)
                        inserted.append(transaction.header)
                    }

                    let checkDoubleSpend = !transaction.header.isOutgoing && !inBlock
                    if !skipCheckBloomFilter {
                        needToUpdateBloomFilter = needToUpdateBloomFilter ||
                                                  checkDoubleSpend ||
                                                  self.publicKeyManager.gapShifts() ||
                                                  self.irregularOutputFinder.hasIrregularOutput(outputs: transaction.outputs)
                    }
                } else if existPending {
                    notMineTransactions.insert(probablyNotMineTransaction)                                  // add notMine tx hash to set

                    let pendingTxHashes = storage.incomingPendingTransactionHashes()
                    if pendingTxHashes.isEmpty {
                        continue
                    }

                    let conflictingTransactionHashes = storage
                            .inputs(byHashes: pendingTxHashes)
                            .filter { input in
                                transaction.inputs.contains { $0.previousOutputIndex == input.previousOutputIndex && $0.previousOutputTxHash == input.previousOutputTxHash }
                            }
                            .map { $0.transactionHash }
                    if conflictingTransactionHashes.isEmpty {                                               // handle if transaction has conflicting inputs, otherwise it's false-positive tx
                        continue
                    }

                    try Array(Set(conflictingTransactionHashes))                                            // make unique elements
                            .compactMap { storage.transaction(byHash: $0) }                                 // get transactions for each input
                            .filter { $0.blockHash == nil }                                                 // exclude all transactions in blocks
                            .forEach {                                                                      // update conflicting transactions
                                if !inBlock {                                                               // if coming other tx is pending only update conflict status
                                    $0.conflictingTxHash = transaction.header.dataHash
                                    try storage.update(transaction: $0)
                                    updated.append($0)
                                } else {                                                                    // if coming other tx in block invalidate our tx
                                    needToUpdateBloomFilter = true
                                    processInvalid(transactionHash: $0.dataHash, conflictingTxHash: transaction.header.dataHash)
                                }
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

    public func processInvalid(transactionHash: Data, conflictingTxHash: Data?) {
        let invalidTransactionsFullInfo = descendantTransactionsFullInfo(of: transactionHash)

        guard !invalidTransactionsFullInfo.isEmpty else {
            return
        }

        invalidTransactionsFullInfo.forEach {
            $0.transactionWithBlock.transaction.status = .invalid
            if let conflictingTxHash = conflictingTxHash {
                $0.transactionWithBlock.transaction.conflictingTxHash = conflictingTxHash
            }
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
