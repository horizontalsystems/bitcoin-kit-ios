import GRDB

public class PeerAddress: Record {
    let ip: String
    var score: Int

    public init(ip: String, score: Int) {
        self.ip = ip
        self.score = score

        super.init()
    }

    override open class var databaseTableName: String {
        return "peerAddresses"
    }

    enum Columns: String, ColumnExpression {
        case ip
        case score
    }

    required init(row: Row) {
        ip = row[Columns.ip]
        score = row[Columns.score]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.ip] = ip
        container[Columns.score] = score
    }

}
