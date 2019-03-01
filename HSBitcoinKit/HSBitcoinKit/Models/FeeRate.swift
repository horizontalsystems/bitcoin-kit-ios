import Foundation
import GRDB
import ObjectMapper

class FeeRate: Record, ImmutableMappable {
    static let defaultFeeRate = FeeRate(
            lowPriority: Decimal(string: "0.00022145")!,
            mediumPriority: Decimal(string: "0.00043533")!,
            highPriority: Decimal(string: "0.00083319")!,
            date: Date(timeIntervalSince1970: 1543211299660)
    ) // real main-net feeRate for kB at 26 november

    private static let primaryKey = "primaryKey"

    private let primaryKey: String = FeeRate.primaryKey

    private let lowPriority: Decimal
    private let mediumPriority: Decimal
    private let highPriority: Decimal
    private let date: Date

    init(lowPriority: Decimal, mediumPriority: Decimal, highPriority: Decimal, date: Date) {
        self.lowPriority = lowPriority
        self.mediumPriority = mediumPriority
        self.highPriority = highPriority
        self.date = date

        super.init()
    }

    var low: Int { return valueInSatoshi(value: lowPriority) }
    var medium: Int { return valueInSatoshi(value: mediumPriority) }
    var high: Int { return valueInSatoshi(value: highPriority) }

    private func valueInSatoshi(value: Decimal) -> Int {
        let convertedValue = value * 100_000_000 / 1024

        let handler = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        let intValue = NSDecimalNumber(decimal: convertedValue).rounding(accordingToBehavior: handler).intValue

        return max(intValue, 1)
    }

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
        lowPriority = Decimal(string: row[Columns.lowPriority]) ?? 0
        mediumPriority = Decimal(string: row[Columns.mediumPriority]) ?? 0
        highPriority = Decimal(string: row[Columns.highPriority]) ?? 0
        date = row[Columns.date]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.primaryKey] = primaryKey
        container[Columns.lowPriority] = NSDecimalNumber(decimal: lowPriority).stringValue
        container[Columns.mediumPriority] = NSDecimalNumber(decimal: mediumPriority).stringValue
        container[Columns.highPriority] = NSDecimalNumber(decimal: highPriority).stringValue
        container[Columns.date] = date
    }

    required init(map: Map) throws {
        lowPriority = try map.value("low_priority", using: FeeRate.decimalTransform)
        mediumPriority = try map.value("medium_priority", using: FeeRate.decimalTransform)
        highPriority = try map.value("high_priority", using: FeeRate.decimalTransform)
        date = try map.value("date", using: DateTransform(unit: .milliseconds))

        super.init()
    }

    private static let decimalTransform = TransformOf<Decimal, String>(fromJSON: { (value: String?) -> Decimal? in
        return value.flatMap { Decimal(string: $0) }
    }, toJSON: { (value: Decimal?) -> String? in
        return value.map { NSDecimalNumber(decimal: $0).stringValue }
    })

}
