import Foundation
import GRDB
import ObjectMapper

public enum FeePriority {
    case lowest
    case low
    case medium
    case high
    case highest
    case custom(feeRate: Int)
}

class FeeRate: Record {
    static let defaultFeeRate: FeeRate = FeeRate(low: 21, medium: 42, high: 81, date: Date(timeIntervalSince1970: 1543211299))

    private static let primaryKey = "primaryKey"

    private let primaryKey: String = FeeRate.primaryKey

    init(low: Int, medium: Int, high: Int, date: Date) {
        self.low = low
        self.medium = medium
        self.high = high
        self.date = date

        super.init()
    }

    let low: Int
    let medium: Int
    let high: Int

    let date: Date

    override class var databaseTableName: String {
        return "feeRates"
    }

    enum Columns: String, ColumnExpression {
        case primaryKey
        case lowPriority
        case mediumPriority
        case highPriority
        case date
    }

    required init(row: Row) {
        low = row[Columns.lowPriority]
        medium = row[Columns.mediumPriority]
        high = row[Columns.highPriority]
        date = row[Columns.date]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.primaryKey] = primaryKey
        container[Columns.lowPriority] = low
        container[Columns.mediumPriority] = medium
        container[Columns.highPriority] = high
        container[Columns.date] = date
    }

}
