import RealmSwift
import RxSwift

class TransactionProcessor {
    private let extractor: ITransactionExtractor
    private let linker: ITransactionLinker

    init(extractor: ITransactionExtractor, linker: ITransactionLinker) {
        self.extractor = extractor
        self.linker = linker
    }

}

extension TransactionProcessor: ITransactionProcessor {

    func process(transaction: Transaction, realm: Realm) {
        extractor.extract(transaction: transaction, realm: realm)
        linker.handle(transaction: transaction, realm: realm)
    }

}
