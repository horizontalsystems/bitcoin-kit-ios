import Foundation
import HSCryptoKit

struct InventoryItem {
    /// Identifies the object type linked to this inventory
    let type: Int32
    /// Hash of the object
    let hash: Data

    init(type: Int32, hash: Data) {
        self.type = type
        self.hash = hash
    }

    init(byteStream: ByteStream) {
        type = byteStream.read(Int32.self)
        hash = byteStream.read(Data.self, count: 32)
    }

    func serialized() -> Data {
        var data = Data()
        data += type
        data += hash
        return data
    }

    var objectType: ObjectType {
        switch type {
        case 0:
            return .error
        case 1:
            return .transaction
        case 2:
            return .blockMessage
        case 3:
            return .filteredBlockMessage
        case 4:
            return .compactBlockMessage
        default:
            return .unknown
        }
    }

    enum ObjectType: Int32 {
        /// Any data of with this number may be ignored
        case error = 0
        /// Hash is related to a transaction
        case transaction = 1
        /// Hash is related to a data block
        case blockMessage = 2
        /// Hash of a block header; identical to MSG_BLOCK. Only to be used in getdata message.
        /// Indicates the reply should be a merkleblock message rather than a block message;
        /// this only works if a bloom filter has been set.
        case filteredBlockMessage = 3
        /// Hash of a block header; identical to MSG_BLOCK. Only to be used in getdata message.
        /// Indicates the reply should be a cmpctblock message. See BIP 152 for more info.
        case compactBlockMessage = 4
        case unknown
    }

}
