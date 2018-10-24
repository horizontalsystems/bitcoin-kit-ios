import Foundation
import RealmSwift

class TransactionInput: Object {
    @objc dynamic var previousOutputTxReversedHex = ""
    @objc dynamic var previousOutputIndex: Int = 0
    @objc dynamic var signatureScript = Data()
    @objc dynamic var sequence: Int = 0xFFFFFFFF
    @objc dynamic var previousOutput: TransactionOutput? = nil
    @objc dynamic var keyHash: Data?
    @objc dynamic var address: String?

    var witnessData = List<Data>()

    let transactions = LinkingObjects(fromType: Transaction.self, property: "inputs")
    var transaction: Transaction? {
        return self.transactions.first
    }

    convenience init(withPreviousOutputTxReversedHex previousOutputTxReversedHex: String, previousOutputIndex: Int, script: Data, sequence: Int) {
        self.init()

        self.previousOutputTxReversedHex = previousOutputTxReversedHex
        self.previousOutputIndex = previousOutputIndex
        signatureScript = script
        self.sequence = 0xFFFFFFFF
    }

}

enum SerializationError: Error {
    case noPreviousOutput
    case noPreviousTransaction
}
