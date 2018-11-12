import Foundation
import HSCryptoKit
import RealmSwift

class SentTransaction: Object {
    @objc dynamic var reversedHashHex: String = ""
    @objc dynamic var firstSendTime: Double = CACurrentMediaTime()
    @objc dynamic var lastSendTime: Double = CACurrentMediaTime()
    @objc dynamic var retriesCount: Int = 0

    override class func primaryKey() -> String? {
        return "reversedHashHex"
    }

    convenience init(reversedHashHex: String) {
        self.init()

        self.reversedHashHex = reversedHashHex
    }

}
