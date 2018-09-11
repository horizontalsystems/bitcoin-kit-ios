import Foundation
import RealmSwift

class KitState: Object {

    @objc dynamic var uniqueStubField = ""
    @objc dynamic var apiSynced = false

    override class func primaryKey() -> String? {
        return "uniqueStubField"
    }

}
