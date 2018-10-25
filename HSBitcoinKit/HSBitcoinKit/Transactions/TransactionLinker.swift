import RealmSwift

class TransactionLinker: ITransactionLinker {

    func handle(transaction: Transaction, realm: Realm) {
        for input in transaction.inputs {
            if let previousTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", input.previousOutputTxReversedHex).last,
               previousTransaction.outputs.count > input.previousOutputIndex {
                let previousOutput = previousTransaction.outputs[input.previousOutputIndex]
                input.previousOutput = previousOutput
                input.address = previousOutput.address
                input.keyHash = previousOutput.keyHash
                transaction.isMine = true
            }
        }
    }
}
