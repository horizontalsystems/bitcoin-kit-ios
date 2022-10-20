import Foundation
import GRDB

public class InvalidTransaction: Transaction {

    init(uid: String, dataHash: Data, version: Int, lockTime: Int, timestamp: Int, order: Int, blockHash: Data?, isMine: Bool, isOutgoing: Bool, status: TransactionStatus,
         segWit: Bool, conflictingTxHash: Data?, transactionInfoJson: Data, rawTransaction: String) {
        super.init()

        self.uid = uid
        self.dataHash = dataHash
        self.version = version
        self.lockTime = lockTime
        self.timestamp = timestamp
        self.order = order
        self.blockHash = blockHash
        self.isMine = isMine
        self.isOutgoing = isOutgoing
        self.status = status
        self.segWit = segWit
        self.conflictingTxHash = conflictingTxHash
        self.transactionInfoJson = transactionInfoJson
        self.rawTransaction = rawTransaction
    }

    required init(row: Row) {
        super.init(row: row)
    }


    override open class var databaseTableName: String {
        "invalid_transactions"
    }

}
