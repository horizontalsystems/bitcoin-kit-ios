import GRDB

class SentTransaction: Record {
    let reversedHashHex: String
    var firstSendTime: Double
    var lastSendTime: Double
    var retriesCount: Int

    init(reversedHashHex: String, firstSendTime: Double, lastSendTime: Double, retriesCount: Int) {
        self.reversedHashHex = reversedHashHex
        self.firstSendTime = firstSendTime
        self.lastSendTime = lastSendTime
        self.retriesCount = retriesCount

        super.init()
    }

    override class var databaseTableName: String {
        return "sentTransactions"
    }

    convenience init(reversedHashHex: String) {
        self.init(reversedHashHex: reversedHashHex, firstSendTime: CACurrentMediaTime(), lastSendTime: CACurrentMediaTime(), retriesCount: 0)
    }

    enum Columns: String, ColumnExpression {
        case reversedHashHex
        case firstSendTime
        case lastSendTime
        case retriesCount
    }

    required init(row: Row) {
        reversedHashHex = row[Columns.reversedHashHex]
        firstSendTime = row[Columns.firstSendTime]
        lastSendTime = row[Columns.lastSendTime]
        retriesCount = row[Columns.retriesCount]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.reversedHashHex] = reversedHashHex
        container[Columns.firstSendTime] = firstSendTime
        container[Columns.lastSendTime] = lastSendTime
        container[Columns.retriesCount] = retriesCount
    }

}
