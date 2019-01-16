import RealmSwift
import RxSwift

class TransactionProcessor {
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let linker: ITransactionLinker
    private let addressManager: IAddressManager
    private let dateGenerator: () -> Date

    init(outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, linker: ITransactionLinker, outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IAddressManager,
         dateGenerator: @escaping () -> Date = Date.init) {
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.linker = linker
        self.addressManager = addressManager
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

        for (index, transaction) in transactions.inTopologicalOrder().enumerated() {
            if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                relay(transaction: existingTransaction, withOrder: index, inBlock: block)
                continue
            }

            process(transaction: transaction, realm: realm)

            if transaction.isMine {
                relay(transaction: transaction, withOrder: index, inBlock: block)
                realm.add(transaction)

                if !skipCheckBloomFilter {
                    needToUpdateBloomFilter = needToUpdateBloomFilter || self.addressManager.gapShifts() || self.hasUnspentOutputs(transaction: transaction)
                }
            }
        }

        if needToUpdateBloomFilter {
            throw BloomFilterManager.BloomFilterExpired()
        }
    }

    func process(transaction: Transaction, realm: Realm) {
        outputExtractor.extract(transaction: transaction)
        linker.handle(transaction: transaction, realm: realm)

        guard transaction.isMine else {
            return
        }
        outputAddressExtractor.extractOutputAddresses(transaction: transaction)
        inputExtractor.extract(transaction: transaction)
    }

}
