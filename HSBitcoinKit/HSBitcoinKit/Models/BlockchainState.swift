import GRDB

class BlockchainState: Record {
    private static let primaryKey = "primaryKey"

    private let primaryKey: String = BlockchainState.primaryKey

    var initialRestored: Bool?

    override class var databaseTableName: String {
        return "blockchainStates"
    }

    override init() {
        super.init()
    }

    enum Columns: String, ColumnExpression {
        case primaryKey
        case initialRestored
    }

    required init(row: Row) {
        initialRestored = row[Columns.initialRestored]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.primaryKey] = primaryKey
        container[Columns.initialRestored] = initialRestored
    }

}
