import GRDB

class InstantTransactionHash: Record {
    let txHash: Data

    override class var databaseTableName: String {
        return "instantTransactionHashes"
    }

    enum Columns: String, ColumnExpression {
        case txHash
    }

    required init(row: Row) {
        txHash = row[Columns.txHash]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.txHash] = txHash
    }

    init(txHash: Data) {
        self.txHash = txHash

        super.init()
    }

}
