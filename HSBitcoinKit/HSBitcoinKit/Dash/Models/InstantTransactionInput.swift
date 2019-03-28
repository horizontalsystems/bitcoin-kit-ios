import GRDB

class InstantTransactionInput: Record {
    let txHash: Data
    let inputTxHash: Data
    let timeCreated: Int
    let voteCount: Int
    let blockHeight: Int?

    override class var databaseTableName: String {
        return "instantTransactionInputs"
    }

    enum Columns: String, ColumnExpression {
        case txHash
        case inputTxHash
        case timeCreated
        case voteCount
        case blockHeight
    }

    required init(row: Row) {
        txHash = row[Columns.txHash]
        inputTxHash = row[Columns.inputTxHash]
        timeCreated = row[Columns.timeCreated]
        voteCount = row[Columns.voteCount]
        blockHeight = row[Columns.blockHeight]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.txHash] = txHash
        container[Columns.inputTxHash] = inputTxHash
        container[Columns.timeCreated] = timeCreated
        container[Columns.voteCount] = voteCount
        container[Columns.blockHeight] = blockHeight
    }

    init(txHash: Data, inputTxHash: Data, timeCreated: Int, voteCount: Int, blockHeight: Int?) {
        self.txHash = txHash
        self.inputTxHash = inputTxHash
        self.timeCreated = timeCreated
        self.voteCount = voteCount
        self.blockHeight = blockHeight

        super.init()
    }

}
