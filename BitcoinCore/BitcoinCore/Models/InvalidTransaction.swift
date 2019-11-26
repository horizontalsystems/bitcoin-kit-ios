import Foundation
import HSCryptoKit
import GRDB

class InvalidTransaction: Transaction {

    let transactionInfoJson: Data

    init(dataHash: Data, version: Int, lockTime: Int, timestamp: Int, order: Int, blockHash: Data?, isMine: Bool, isOutgoing: Bool, status: TransactionStatus, segWit: Bool, transactionInfoJson: Data) {
        self.transactionInfoJson = transactionInfoJson

        super.init()

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
    }


    override open class var databaseTableName: String {
        "invalid_transactions"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case transactionInfoJson
    }

    required init(row: Row) {
        transactionInfoJson = row[Columns.transactionInfoJson]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        super.encode(to: &container)
        container[Columns.transactionInfoJson] = transactionInfoJson
    }

}
