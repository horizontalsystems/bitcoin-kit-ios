import Foundation
import RealmSwift

class FeeRate: Object {
    static let defaultFeeRate = FeeRate(dateInterval: 1543211299660, date: "2018-11-26 05:48", low: 0.00022145, medium: 0.00043533, high: 0.00083319) // real main-net feeRate for kB at 26 november
    static let key = "fee_rate_key"

    @objc dynamic var lowPriority: Double = 0
    @objc dynamic var mediumPriority: Double = 0
    @objc dynamic var highPriority: Double = 0
    @objc dynamic var date: String = ""
    @objc dynamic var dateInterval: Int = 0

    @objc dynamic var primaryKey: String = FeeRate.key

    override class func primaryKey() -> String? {
        return "primaryKey"
    }

    convenience init(dateInterval: Int, date: String, low: Double, medium: Double, high: Double) {
        self.init()

        self.lowPriority = low
        self.mediumPriority = medium
        self.highPriority = high

        self.dateInterval = dateInterval
        self.date = date
    }

}
