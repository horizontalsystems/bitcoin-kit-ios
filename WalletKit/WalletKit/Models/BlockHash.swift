import Foundation
import RealmSwift

class BlockHash: Object {
    @objc dynamic var reversedHeaderHashHex = ""
    @objc dynamic var headerHash = Data()
    @objc dynamic var height: Int = 0
    @objc dynamic var order: Int = 0

    override class func primaryKey() -> String? {
        return "reversedHeaderHashHex"
    }

    convenience init(withHeaderHash headerHash: Data, height: Int, order: Int = 0) {
        self.init()

        self.headerHash = headerHash
        self.reversedHeaderHashHex = headerHash.reversedHex
        self.height = height
        self.order = order
    }

}
