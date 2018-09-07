import Foundation

enum AddressType: UInt8 { case pubKeyHash = 0, scriptHash = 8 }

struct Address: Equatable {
    let type: AddressType
    let keyHash: Data
    let base58: String

    var string: String { return base58 }

    var scriptType: ScriptType {
        switch type {
            case .pubKeyHash: return .p2pkh
            case .scriptHash: return .p2sh
        }
    }

    static func ==(lhs: Address, rhs: Address) -> Bool {
        return lhs.type == rhs.type && lhs.keyHash == rhs.keyHash
    }

}
