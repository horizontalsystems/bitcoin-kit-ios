import GRDB

class MasternodeListState: Record {
    private static let primaryKey = "primaryKey"

    let baseBlockHash: Data

    private let primaryKey: String = MasternodeListState.primaryKey

    override class var databaseTableName: String {
        return "masternodeListState"
    }

    enum Columns: String, ColumnExpression {
        case primaryKey
        case baseBlockHash
    }

    required init(row: Row) {
        baseBlockHash = row[Columns.baseBlockHash]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.primaryKey] = primaryKey
        container[Columns.baseBlockHash] = baseBlockHash
    }

    init(baseBlockHash: Data) {
        self.baseBlockHash = baseBlockHash

        super.init()
    }

}
