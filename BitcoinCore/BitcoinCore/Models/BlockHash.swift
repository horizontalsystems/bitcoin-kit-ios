import GRDB

class BlockHash: Record {
    let headerHashReversedHex: String
    let headerHash: Data
    let height: Int
    let sequence: Int

    init(headerHash: Data, height: Int, order: Int) {
        self.headerHash = headerHash
        self.headerHashReversedHex = headerHash.reversedHex
        self.height = height
        self.sequence = order

        super.init()
    }

    init?(headerHashReversedHex: String, height: Int, sequence: Int) {
        guard let headerHash = Data(hex: headerHashReversedHex) else {
            return nil
        }

        self.headerHashReversedHex = headerHashReversedHex
        self.headerHash = Data(headerHash.reversed())
        self.height = height
        self.sequence = sequence

        super.init()
    }

    override class var databaseTableName: String {
        return "blockHashes"
    }

    enum Columns: String, ColumnExpression {
        case headerHashReversedHex
        case headerHash
        case height
        case sequence
    }

    required init(row: Row) {
        headerHashReversedHex = row[Columns.headerHashReversedHex]
        headerHash = row[Columns.headerHash]
        height = row[Columns.height]
        sequence = row[Columns.sequence]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.headerHashReversedHex] = headerHashReversedHex
        container[Columns.headerHash] = headerHash
        container[Columns.height] = height
        container[Columns.sequence] = sequence
    }

}

extension BlockHash: Equatable {

    public static func ==(lhs: BlockHash, rhs: BlockHash) -> Bool {
        return lhs.headerHashReversedHex == rhs.headerHashReversedHex
    }

}

extension BlockHash: Hashable {

    var hashValue: Int {
        return headerHash.hashValue ^ height.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(headerHash)
        hasher.combine(height)
    }

}
