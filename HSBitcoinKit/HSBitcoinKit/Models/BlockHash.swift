import GRDB

class BlockHash: Record {
    let reversedHeaderHashHex: String
    let headerHash: Data
    let height: Int
    let order: Int

    init(headerHash: Data, height: Int, order: Int) {
        self.headerHash = headerHash
        self.reversedHeaderHashHex = headerHash.reversedHex
        self.height = height
        self.order = order

        super.init()
    }

    init?(reversedHeaderHashHex: String, height: Int, order: Int) {
        guard let headerHash = Data(hex: reversedHeaderHashHex) else {
            return nil
        }

        self.reversedHeaderHashHex = reversedHeaderHashHex
        self.headerHash = headerHash
        self.height = height
        self.order = order

        super.init()
    }

    override class var databaseTableName: String {
        return "blockHashes"
    }

    enum Columns: String, ColumnExpression {
        case reversedHeaderHashHex
        case headerHash
        case height
        case order
    }

    required init(row: Row) {
        reversedHeaderHashHex = row[Columns.reversedHeaderHashHex]
        headerHash = row[Columns.headerHash]
        height = row[Columns.height]
        order = row[Columns.order]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.reversedHeaderHashHex] = reversedHeaderHashHex
        container[Columns.headerHash] = headerHash
        container[Columns.height] = height
        container[Columns.order] = order
    }

}

extension BlockHash: Equatable {

    public static func ==(lhs: BlockHash, rhs: BlockHash) -> Bool {
        return lhs.reversedHeaderHashHex == rhs.reversedHeaderHashHex
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
