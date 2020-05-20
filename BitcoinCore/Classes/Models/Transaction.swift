import Foundation
import GRDB

public enum TransactionStatus: Int, DatabaseValueConvertible, Codable { case new, relayed, invalid }

public class Transaction: Record {
    public var uid: String
    public var dataHash: Data
    public var version: Int
    public var lockTime: Int
    public var timestamp: Int
    public var order: Int
    public var blockHash: Data? = nil
    public var isMine: Bool = false
    public var isOutgoing: Bool = false
    public var status: TransactionStatus = .relayed
    public var segWit: Bool = false
    public var conflictingTxHash: Data? = nil
    public var transactionInfoJson: Data = Data()
    public var rawTransaction: String? = nil

    public init(version: Int = 0, lockTime: Int = 0, timestamp: Int? = nil) {
        self.version = version
        self.lockTime = lockTime
        self.timestamp = timestamp ?? Int(Date().timeIntervalSince1970)
        self.order = 0
        self.dataHash = Data()
        self.uid = UUID().uuidString

        super.init()
    }


    override open class var databaseTableName: String {
        "transactions"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case uid
        case dataHash
        case version
        case lockTime
        case timestamp
        case order
        case blockHash
        case isMine
        case isOutgoing
        case status
        case segWit
        case conflictingTxHash
        case transactionInfoJson
        case rawTransaction
    }

    required init(row: Row) {
        uid = row[Columns.uid]
        dataHash = row[Columns.dataHash]
        version = row[Columns.version]
        lockTime = row[Columns.lockTime]
        timestamp = row[Columns.timestamp]
        order = row[Columns.order]
        blockHash = row[Columns.blockHash]
        isMine = row[Columns.isMine]
        isOutgoing = row[Columns.isOutgoing]
        status = row[Columns.status]
        segWit = row[Columns.segWit]
        conflictingTxHash = row[Columns.conflictingTxHash]
        transactionInfoJson = row[Columns.transactionInfoJson]
        rawTransaction = row[Columns.rawTransaction]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.uid] = uid
        container[Columns.dataHash] = dataHash
        container[Columns.version] = version
        container[Columns.lockTime] = lockTime
        container[Columns.timestamp] = timestamp
        container[Columns.order] = order
        container[Columns.blockHash] = blockHash
        container[Columns.isMine] = isMine
        container[Columns.isOutgoing] = isOutgoing
        container[Columns.status] = status
        container[Columns.segWit] = segWit
        container[Columns.conflictingTxHash] = conflictingTxHash
        container[Columns.transactionInfoJson] = transactionInfoJson
        container[Columns.rawTransaction] = rawTransaction
    }

}
