import RealmSwift
import RxSwift

class TransactionProcessor {
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let linker: ITransactionLinker
    private let addressManager: IAddressManager

    weak var listener: IBlockchainDataListener?

    private let dateGenerator: () -> Date

    init(outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, linker: ITransactionLinker, outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IAddressManager, listener: IBlockchainDataListener? = nil,
         dateGenerator: @escaping () -> Date = Date.init) {
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.linker = linker
        self.addressManager = addressManager
        self.listener = listener
        self.dateGenerator = dateGenerator
    }

    private func hasUnspentOutputs(transaction: Transaction) -> Bool {
        for output in transaction.outputs {
            if output.publicKey != nil, (output.scriptType == .p2wpkh || output.scriptType == .p2pk)  {
                return true
            }
        }

        return false
    }

    func relay(transaction: Transaction, withOrder order: Int, inBlock block: Block?) {
        transaction.block = block
        transaction.status = .relayed
        transaction.timestamp = block?.header?.timestamp ?? Int(dateGenerator().timeIntervalSince1970)
        transaction.order = order
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func process(transactions: [Transaction], inBlock block: Block?, skipCheckBloomFilter: Bool, realm: Realm) throws {
        var needToUpdateBloomFilter = false

        var updated = [Transaction]()
        var inserted = [Transaction]()
        for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
            if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                relay(transaction: existingTransaction, withOrder: index, inBlock: block)
                updated.append(existingTransaction)
                continue
            }

            process(transaction: transaction, realm: realm)

            if transaction.isMine {
                relay(transaction: transaction, withOrder: index, inBlock: block)
                realm.add(transaction)
                inserted.append(transaction)

                if !skipCheckBloomFilter {
                    needToUpdateBloomFilter = needToUpdateBloomFilter || self.addressManager.gapShifts() || self.hasUnspentOutputs(transaction: transaction)
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

    func processOutgoing(transaction: Transaction, realm: Realm) throws {
        try realm.write {
            realm.add(transaction)
            process(transaction: transaction, realm: realm)

            listener?.onUpdate(updated: [], inserted: [transaction])
        }
    }

    private func process(transaction: Transaction, realm: Realm) {
        outputExtractor.extract(transaction: transaction)
        linker.handle(transaction: transaction, realm: realm)

        guard transaction.isMine else {
            return
        }
        outputAddressExtractor.extractOutputAddresses(transaction: transaction)
        inputExtractor.extract(transaction: transaction)
    }

}
