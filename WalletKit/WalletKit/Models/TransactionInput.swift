import Foundation
import RealmSwift

public class TransactionInput: Object {
    @objc dynamic var previousOutputTxReversedHex = ""
    @objc dynamic var previousOutputIndex: Int = 0
    @objc dynamic var signatureScript = Data()
    @objc dynamic var sequence: Int = 0
    @objc public dynamic var previousOutput: TransactionOutput? = nil
    @objc dynamic var keyHash: Data?
    @objc public dynamic var address: String?

    let transactions = LinkingObjects(fromType: Transaction.self, property: "inputs")
    var transaction: Transaction? {
        return self.transactions.first
    }

    convenience init(withPreviousOutputTxReversedHex previousOutputTxReversedHex: String, previousOutputIndex: Int, script: Data, sequence: Int) {
        self.init()

        self.previousOutputTxReversedHex = previousOutputTxReversedHex
        self.previousOutputIndex = previousOutputIndex
        signatureScript = script
        self.sequence = sequence
    }

}

enum SerializationError: Error {
    case noPreviousOutput
    case noPreviousTransaction
}
