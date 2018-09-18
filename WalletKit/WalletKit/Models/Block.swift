import Foundation
import RealmSwift

class Block: Object {
    enum BlockError: Error { case noHeader }

    @objc enum Status: Int { case pending, syncing, synced }

    @objc dynamic var reversedHeaderHashHex = ""
    @objc dynamic var headerHash = Data()
    @objc dynamic var height: Int = 0
    @objc dynamic var status: Status = .pending

    @objc dynamic var header: BlockHeader?
    @objc dynamic var previousBlock: Block?

    let transactions = LinkingObjects(fromType: Transaction.self, property: "block")

    override class func primaryKey() -> String? {
        return "reversedHeaderHashHex"
    }

    convenience init(withHeader header: BlockHeader?, previousBlock: Block) {
        self.init(withHeader: header)

        height = previousBlock.height + 1
        self.previousBlock = previousBlock
    }

    convenience init(withHeader header: BlockHeader, height: Int) {
        self.init(withHeader: header)

        self.height = height
    }

    convenience init(withHeaderHash headerHash: Data, height: Int) {
        self.init()

        self.headerHash = headerHash
        self.reversedHeaderHashHex = headerHash.reversedHex
        self.height = height
    }

    private convenience init(withHeader header: BlockHeader?) {
        self.init()

        if let header = header {
            self.header = header
            headerHash = Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: header))
            reversedHeaderHashHex = headerHash.reversedHex
        }
    }

}
