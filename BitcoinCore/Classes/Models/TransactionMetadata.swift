import Foundation
import GRDB

public enum TransactionType: Int, DatabaseValueConvertible, Codable {
    case incoming = 1
    case outgoing = 2
    case sentToSelf = 3
}

public enum TransactionFilterType {
    case incoming, outgoing

    var types: [TransactionType] {
        switch self {
        case .incoming: return [.incoming, .sentToSelf]
        case .outgoing: return [.outgoing, .sentToSelf]
        }
    }
}


public class TransactionMetadata: Record {
    public var transactionHash: Data
    public var amount: Int
    public var type: TransactionType
    public var fee: Int?

    public init(transactionHash: Data = Data(), amount: Int = 0, type: TransactionType = .incoming, fee: Int? = nil) {
        self.transactionHash = transactionHash
        self.amount = amount
        self.type = type
        self.fee = fee

        super.init()
    }

    override open class var databaseTableName: String {
        "transaction_metadata"
    }
    
    enum Columns: String, ColumnExpression, CaseIterable {
        case transactionHash
        case amount
        case type
        case fee
    }
    
    required init(row: Row) {
        transactionHash = row[Columns.transactionHash]
        amount = row[Columns.amount]
        type = row[Columns.type]
        fee = row[Columns.fee]

        super.init(row: row)
    }
    
    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.transactionHash] = transactionHash
        container[Columns.amount] = amount
        container[Columns.type] = type
        container[Columns.fee] = fee
    }
    
}
