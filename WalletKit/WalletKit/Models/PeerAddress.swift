import Foundation
import RealmSwift

class PeerAddress: Object {
    @objc dynamic var ip: String = ""
    @objc dynamic var score: Int = 0
    @objc dynamic var using: Bool = false

    override class func primaryKey() -> String? {
        return "ip"
    }

    convenience init(ip: String, score: Int, using: Bool) {
        self.init()

        self.ip = ip
        self.score = score
        self.using = using
    }

    var hashCode: Int {
        return ip.hash
    }

}
