import RealmSwift

class TransactionLinker: ITransactionLinker {

    func handle(transaction: Transaction, realm: Realm) {
        for input in transaction.inputs {
            if let previousTransaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", input.previousOutputTxReversedHex).last {
                if previousTransaction.outputs.count <= input.previousOutputIndex {
                    continue
                }

                let previousOutput = previousTransaction.outputs[input.previousOutputIndex]
                if previousOutput.publicKey == nil {
                    continue
                }

                input.previousOutput = previousOutput
                input.address = previousOutput.address
                input.keyHash = previousOutput.keyHash
                transaction.isMine = true
            }
        }
    }
}
