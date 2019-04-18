import GRDB

public class SentTransaction: Record {
    let hashReversedHex: String
    var firstSendTime: Double
    var lastSendTime: Double
    var retriesCount: Int

    init(hashReversedHex: String, firstSendTime: Double, lastSendTime: Double, retriesCount: Int) {
        self.hashReversedHex = hashReversedHex
        self.firstSendTime = firstSendTime
        self.lastSendTime = lastSendTime
        self.retriesCount = retriesCount

        super.init()
    }

    override open class var databaseTableName: String {
        return "sentTransactions"
    }

    convenience init(hashReversedHex: String) {
        self.init(hashReversedHex: hashReversedHex, firstSendTime: CACurrentMediaTime(), lastSendTime: CACurrentMediaTime(), retriesCount: 0)
    }

    enum Columns: String, ColumnExpression {
        case hashReversedHex
        case firstSendTime
        case lastSendTime
        case retriesCount
    }

    required init(row: Row) {
        hashReversedHex = row[Columns.hashReversedHex]
        firstSendTime = row[Columns.firstSendTime]
        lastSendTime = row[Columns.lastSendTime]
        retriesCount = row[Columns.retriesCount]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.hashReversedHex] = hashReversedHex
        container[Columns.firstSendTime] = firstSendTime
        container[Columns.lastSendTime] = lastSendTime
        container[Columns.retriesCount] = retriesCount
    }

}
