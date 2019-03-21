import Foundation
import RealmSwift
import ObjectMapper

public enum FeePriority {
    case lowest
    case low
    case medium
    case high
    case highest
    case custom(gasPriceInWei: Int)
}

class FeeRate: Object {
    static let defaultFeeRate: FeeRate = { _ -> FeeRate in
        let rate = FeeRate()
        rate.lowPriority = 21
        rate.mediumPriority = 42
        rate.highPriority = 81
        rate.date = Date(timeIntervalSince1970: 1543211299660)
        return rate
    }(()) // real main-net feeRate for kB at 26 november

    @objc dynamic var lowPriority: Double = 0
    @objc dynamic var mediumPriority: Double = 0
    @objc dynamic var highPriority: Double = 0
    @objc dynamic var date: Date = Date()

    @objc dynamic var primaryKey = "primaryKey"

    override class func primaryKey() -> String? {
        return "primaryKey"
    }

    var low: Int { return Int(lowPriority) }
    var medium: Int { return Int(mediumPriority) }
    var high: Int { return Int(highPriority) }

//    init(lowPriority: Double, mediumPriority: Double, highPriority: Double, date: Date) {
//        self.lowPriority = lowPriority
//        self.mediumPriority = mediumPriority
//        self.highPriority = highPriority
//        self.date = date
//
//        super.init()
//    }

//    override class var databaseTableName: String {
//        return "feeRates"
//    }

//    enum Columns: String, ColumnExpression {
//        case primaryKey
//        case lowPriority
//        case mediumPriority
//        case highPriority
//        case date
//    }

//    required init(row: Row) {
//        lowPriority = Decimal(string: row[Columns.lowPriority]) ?? 0
//        mediumPriority = Decimal(string: row[Columns.mediumPriority]) ?? 0
//        highPriority = Decimal(string: row[Columns.highPriority]) ?? 0
//        date = row[Columns.date]
//
//        super.init(row: row)
//    }

//    override func encode(to container: inout PersistenceContainer) {
//        container[Columns.primaryKey] = primaryKey
//        container[Columns.lowPriority] = lowPriority
//        container[Columns.mediumPriority] = mediumPriority
//        container[Columns.highPriority] = highPriority
//        container[Columns.date] = date
//    }

//    required init(map: Map) throws {
//        self.init()
//
//        lowPriority = try map.value("low_priority")
//        mediumPriority = try map.value("medium_priority")
//        highPriority = try map.value("high_priority")
////        date = try map.value("date", using: DateTransform(unit: .milliseconds))
//    }

}
