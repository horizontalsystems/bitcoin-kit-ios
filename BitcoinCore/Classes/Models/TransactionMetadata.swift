import Foundation
import GRDB

public enum TransactionType: Int, DatabaseValueConvertible, Codable {
    case incoming = 1
    case outgoing = 2
    case sentToSelf = 3
}

public class TransactionMetadata: Record {
    public var hash: Data
    public var amount: Int
    public var type: TransactionType
    public var fee: Int?

    public init(hash: Data = Data(), amount: Int = 0, type: TransactionType = .incoming, fee: Int? = nil) {
        self.hash = hash
        self.amount = amount
        self.type = type
        self.fee = fee

        super.init()
    }

    override open class var databaseTableName: String {
        "transactions_meta_data"
    }
    
    enum Columns: String, ColumnExpression, CaseIterable {
        case hash
        case amount
        case type
        case fee
    }
    
    required init(row: Row) {
        hash = row[Columns.hash]
        amount = row[Columns.amount]
        type = row[Columns.type]
        fee = row[Columns.fee]

        super.init(row: row)
    }
    
    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.hash] = hash
        container[Columns.amount] = amount
        container[Columns.type] = type
        container[Columns.fee] = fee
    }
    
}
