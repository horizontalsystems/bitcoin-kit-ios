import GRDB

class PeerAddress: Record {
    let ip: String
    var score: Int

    init(ip: String, score: Int) {
        self.ip = ip
        self.score = score

        super.init()
    }

    override class var databaseTableName: String {
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

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.ip] = ip
        container[Columns.score] = score
    }

}
