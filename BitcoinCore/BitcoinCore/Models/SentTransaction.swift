import GRDB

public class SentTransaction: Record {
    let dataHash: Data
    var firstSendTime: Double
    var lastSendTime: Double
    var retriesCount: Int

    init(dataHash: Data, firstSendTime: Double, lastSendTime: Double, retriesCount: Int) {
        self.dataHash = dataHash
        self.firstSendTime = firstSendTime
        self.lastSendTime = lastSendTime
        self.retriesCount = retriesCount

        super.init()
    }

    override open class var databaseTableName: String {
        return "sentTransactions"
    }

    convenience init(dataHash: Data) {
        self.init(dataHash: dataHash, firstSendTime: CACurrentMediaTime(), lastSendTime: CACurrentMediaTime(), retriesCount: 0)
    }

    enum Columns: String, ColumnExpression {
        case dataHash
        case firstSendTime
        case lastSendTime
        case retriesCount
    }

    required init(row: Row) {
        dataHash = row[Columns.dataHash]
        firstSendTime = row[Columns.firstSendTime]
        lastSendTime = row[Columns.lastSendTime]
        retriesCount = row[Columns.retriesCount]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.dataHash] = dataHash
        container[Columns.firstSendTime] = firstSendTime
        container[Columns.lastSendTime] = lastSendTime
        container[Columns.retriesCount] = retriesCount
    }

}
