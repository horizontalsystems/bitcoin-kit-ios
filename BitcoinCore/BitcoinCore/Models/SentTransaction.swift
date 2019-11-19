import GRDB

public class SentTransaction: Record {
    let dataHash: Data
    var firstSendTime: Double
    var lastSendTime: Double
    var retriesCount: Int
    var sendSuccess: Bool

    init(dataHash: Data, firstSendTime: Double, lastSendTime: Double, retriesCount: Int, sendSuccess: Bool) {
        self.dataHash = dataHash
        self.firstSendTime = firstSendTime
        self.lastSendTime = lastSendTime
        self.retriesCount = retriesCount
        self.sendSuccess = sendSuccess

        super.init()
    }

    override open class var databaseTableName: String {
        "sentTransactions"
    }

    convenience init(dataHash: Data) {
        self.init(dataHash: dataHash, firstSendTime: CACurrentMediaTime(), lastSendTime: CACurrentMediaTime(), retriesCount: 0, sendSuccess: false)
    }

    enum Columns: String, ColumnExpression {
        case dataHash
        case firstSendTime
        case lastSendTime
        case retriesCount
        case sendSuccess
    }

    required init(row: Row) {
        dataHash = row[Columns.dataHash]
        firstSendTime = row[Columns.firstSendTime]
        lastSendTime = row[Columns.lastSendTime]
        retriesCount = row[Columns.retriesCount]
        sendSuccess = row[Columns.sendSuccess]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.dataHash] = dataHash
        container[Columns.firstSendTime] = firstSendTime
        container[Columns.lastSendTime] = lastSendTime
        container[Columns.retriesCount] = retriesCount
        container[Columns.sendSuccess] = sendSuccess
    }

}
