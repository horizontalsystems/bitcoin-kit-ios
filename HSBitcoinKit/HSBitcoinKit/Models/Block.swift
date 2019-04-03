import HSCryptoKit
import GRDB

class Block: Record {

    var version: Int
    var previousBlockHashReversedHex: String
    var merkleRoot: Data
    var timestamp: Int
    var bits: Int
    var nonce: Int

    var headerHashReversedHex: String
    var headerHash: Data
    var height: Int
    var stale: Bool = false

    func previousBlock(storage: IStorage) -> Block? {
        return storage.block(byHashHex: self.previousBlockHashReversedHex)
    }

    init(withHeader header: BlockHeader, height: Int) {
        version = header.version
        previousBlockHashReversedHex = header.previousBlockHeaderHash.reversedHex
        merkleRoot = header.merkleRoot
        timestamp = header.timestamp
        bits = header.bits
        nonce = header.nonce
        headerHash = header.headerHash
        headerHashReversedHex = headerHash.reversedHex
        self.height = height

        super.init()
    }

    convenience init(withHeader header: BlockHeader, previousBlock: Block) {
        self.init(withHeader: header, height: previousBlock.height + 1)
    }

    override class var databaseTableName: String {
        return "blocks"
    }

    enum Columns: String, ColumnExpression, CaseIterable {
        case version
        case previousBlockHashReversedHex
        case merkleRoot
        case timestamp
        case bits
        case nonce
        case headerHashReversedHex
        case headerHash
        case height
        case stale
    }

    required init(row: Row) {
        version = row[Columns.version]
        previousBlockHashReversedHex = row[Columns.previousBlockHashReversedHex]
        merkleRoot = row[Columns.merkleRoot]
        timestamp = row[Columns.timestamp]
        bits = row[Columns.bits]
        nonce = row[Columns.nonce]
        headerHashReversedHex = row[Columns.headerHashReversedHex]
        headerHash = row[Columns.headerHash]
        height = row[Columns.height]
        stale = row[Columns.stale]

        super.init(row: row)
    }

    override func encode(to container: inout PersistenceContainer) {
        container[Columns.version] = version
        container[Columns.previousBlockHashReversedHex] = previousBlockHashReversedHex
        container[Columns.merkleRoot] = merkleRoot
        container[Columns.timestamp] = timestamp
        container[Columns.bits] = bits
        container[Columns.nonce] = nonce
        container[Columns.headerHashReversedHex] = headerHashReversedHex
        container[Columns.headerHash] = headerHash
        container[Columns.height] = height
        container[Columns.stale] = stale
    }

}
