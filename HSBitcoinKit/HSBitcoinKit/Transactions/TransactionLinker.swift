import RealmSwift

class TransactionLinker: ITransactionLinker {

    func handle(transaction: Transaction, realm: Realm) {
        for input in transaction.inputs {
            if let previousTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", input.previousOutputTxReversedHex).last,
               previousTransaction.outputs.count > input.previousOutputIndex {
                input.previousOutput = previousTransaction.outputs[input.previousOutputIndex]
                transaction.isMine = true
            }
        }
    }
}
