import Foundation
import RealmSwift

public class BlockHeader: Object {
    @objc dynamic var version: Int = 0
    @objc dynamic var previousBlockHeaderHash = Data()
    @objc dynamic var merkleRoot = Data()
    @objc public dynamic var timestamp: Int = 0
    @objc dynamic var bits: Int = 0
    @objc dynamic var nonce: Int = 0

    convenience init(version: Int, previousBlockHeaderReversedHex: String, merkleRootReversedHex: String, timestamp: Int, bits: Int, nonce: Int) {
        self.init()

        self.version = version
        if let data = previousBlockHeaderReversedHex.reversedData {
            previousBlockHeaderHash = data
        }
        if let data = merkleRootReversedHex.reversedData {
            merkleRoot = data
        }
        self.timestamp = timestamp
        self.bits = bits
        self.nonce = nonce
    }

}
