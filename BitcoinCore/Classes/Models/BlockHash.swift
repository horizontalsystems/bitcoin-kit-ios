import GRDB
import UIExtensions

public class BlockHash: Record {
    let headerHash: Data
    let height: Int
    let sequence: Int

    public init(headerHash: Data, height: Int, order: Int) {
        self.headerHash = headerHash
        self.height = height
        self.sequence = order

        super.init()
    }

    init?(headerHashReversedHex: String?, height: Int?, sequence: Int) {
        guard let hex = headerHashReversedHex, let height = height, let headerHash = Data(hex: hex) else {
            return nil
        }

        self.headerHash = Data(headerHash.reversed())
        self.height = height
        self.sequence = sequence

        super.init()
    }

    override open class var databaseTableName: String {
        return "blockHashes"
    }

    enum Columns: String, ColumnExpression {
        case headerHash
        case height
        case sequence
    }

    required init(row: Row) {
        headerHash = row[Columns.headerHash]
        height = row[Columns.height]
        sequence = row[Columns.sequence]

        super.init(row: row)
    }

    override open func encode(to container: inout PersistenceContainer) {
        container[Columns.headerHash] = headerHash
        container[Columns.height] = height
        container[Columns.sequence] = sequence
    }

}

extension BlockHash: Equatable {

    public static func ==(lhs: BlockHash, rhs: BlockHash) -> Bool {
        return lhs.headerHash == rhs.headerHash
    }

}

extension BlockHash: Hashable {

    public var hashValue: Int {
        return headerHash.hashValue ^ height.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(headerHash)
        hasher.combine(height)
    }

}
