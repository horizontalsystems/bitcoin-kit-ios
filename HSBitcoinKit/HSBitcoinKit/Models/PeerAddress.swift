import Foundation
import RealmSwift

class PeerAddress: Object {
    @objc dynamic var ip: String = ""
    @objc dynamic var score: Int = 0

    override class func primaryKey() -> String? {
        return "ip"
    }

    convenience init(ip: String, score: Int) {
        self.init()

        self.ip = ip
        self.score = score
    }

}
