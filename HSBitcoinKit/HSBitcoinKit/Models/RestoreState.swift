import Foundation
import RealmSwift

class RestoreState: Object {

    @objc dynamic var uniqueStubField = ""
    @objc dynamic var restored = false

    override class func primaryKey() -> String? {
        return "uniqueStubField"
    }

}
