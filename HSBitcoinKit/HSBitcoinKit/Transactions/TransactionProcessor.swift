import RxSwift

class TransactionProcessor {
    private let storage: IStorage
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let linker: ITransactionLinker
    private let addressManager: IAddressManager

    weak var listener: IBlockchainDataListener?

    private let dateGenerator: () -> Date
    private let queue: DispatchQueue

    init(storage: IStorage, outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, linker: ITransactionLinker, outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IAddressManager, listener: IBlockchainDataListener? = nil,
         dateGenerator: @escaping () -> Date = Date.init, queue: DispatchQueue = DispatchQueue(label: "Transactions", qos: .background
    )) {
        self.storage = storage
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.linker = linker
        self.addressManager = addressManager
        self.listener = listener
        self.dateGenerator = dateGenerator
        self.queue = queue
    }

    private func hasUnspentOutputs(transaction: FullTransaction) -> Bool {
        for output in transaction.outputs {
            if output.publicKey(storage: storage) != nil, (output.scriptType == .p2wpkh || output.scriptType == .p2pk)  {
                return true
            }
        }

        return false
    }

    private func process(transaction: FullTransaction) {
        outputExtractor.extract(transaction: transaction)
        linker.handle(transaction: transaction)

        guard transaction.header.isMine else {
            return
        }
        outputAddressExtractor.extractOutputAddresses(transaction: transaction)
        inputExtractor.extract(transaction: transaction)
    }

    private func relay(transaction: Transaction, withOrder order: Int, inBlock block: Block?) {
        transaction.blockHashReversedHex = block?.headerHashReversedHex
        transaction.status = .relayed
        transaction.timestamp = block?.timestamp ?? Int(dateGenerator().timeIntervalSince1970)
        transaction.order = order
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func processReceived(transactions: [FullTransaction], inBlock block: Block?, skipCheckBloomFilter: Bool) throws {
        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()

        try queue.sync {
            for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
                if let existingTransaction = self.storage.transaction(byHashHex: transaction.header.dataHashReversedHex) {
                    self.relay(transaction: existingTransaction, withOrder: index, inBlock: block)
                    try self.storage.update(transaction: existingTransaction)
                    updated.append(existingTransaction)
                    continue
                }

                self.process(transaction: transaction)

                if transaction.header.isMine {
                    self.relay(transaction: transaction.header, withOrder: index, inBlock: block)
                    try self.storage.add(transaction: transaction)

                    inserted.append(transaction.header)

                    if !skipCheckBloomFilter {
                        needToUpdateBloomFilter = needToUpdateBloomFilter || self.addressManager.gapShifts() || self.hasUnspentOutputs(transaction: transaction)
                    }
                }
            }
        }

        if !updated.isEmpty || !inserted.isEmpty {
            listener?.onUpdate(updated: updated, inserted: inserted)
        }

        if needToUpdateBloomFilter {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

    func processCreated(transaction: FullTransaction) throws {
        guard storage.transaction(byHashHex: transaction.header.dataHashReversedHex) == nil else {
            throw TransactionCreator.CreationError.transactionAlreadyExists
        }

        process(transaction: transaction)
        try storage.add(transaction: transaction)
        listener?.onUpdate(updated: [], inserted: [transaction.header])
    }

}
