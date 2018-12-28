import RealmSwift
import RxSwift

class TransactionProcessor {
    private let outputExtractor: ITransactionExtractor
    private let inputExtractor: ITransactionExtractor
    private let outputAddressExtractor: ITransactionOutputAddressExtractor
    private let linker: ITransactionLinker
    private let addressManager: IAddressManager

    init(outputExtractor: ITransactionExtractor, inputExtractor: ITransactionExtractor, linker: ITransactionLinker, outputAddressExtractor: ITransactionOutputAddressExtractor, addressManager: IAddressManager) {
        self.outputExtractor = outputExtractor
        self.inputExtractor = inputExtractor
        self.outputAddressExtractor = outputAddressExtractor
        self.linker = linker
        self.addressManager = addressManager
    }

    private func hasUnspentOutputs(transaction: Transaction) -> Bool {
        for output in transaction.outputs {
            if output.publicKey != nil, (output.scriptType == .p2wpkh || output.scriptType == .p2pk)  {
                return true
            }
        }

        return false
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func process(transactions: [Transaction], inBlock block: Block?, skipCheckBloomFilter: Bool, realm: Realm) throws {
        var needToUpdateBloomFilter = false

        for transaction in transactions.inTopologicalOrder() {
            if let existingTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", transaction.reversedHashHex).first {
                existingTransaction.block = block
                existingTransaction.status = .relayed
                continue
            }

            process(transaction: transaction, realm: realm)

            if transaction.isMine {
                transaction.block = block
                transaction.status = .relayed
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
