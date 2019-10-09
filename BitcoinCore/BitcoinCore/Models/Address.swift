import Foundation

public enum AddressType: UInt8 { case pubKeyHash = 0, scriptHash = 8 }

public protocol Address: class {
    var type: AddressType { get }
    var scriptType: ScriptType { get }
    var keyHash: Data { get }
    var stringValue: String { get }
    var lockingScript: Data { get }
}

extension Address {

    var scriptType: ScriptType {
        switch type {
            case .pubKeyHash: return .p2pkh
            case .scriptHash: return .p2sh
        }
    }

}

class LegacyAddress: Address, Equatable {
    let type: AddressType
    let keyHash: Data
    let stringValue: String

    var lockingScript: Data {
        switch type {
        case .pubKeyHash: return OpCode.p2pkhStart + OpCode.push(keyHash) + OpCode.p2pkhFinish
        case .scriptHash: return OpCode.p2shStart + OpCode.push(keyHash) + OpCode.p2shFinish
        }
    }

    init(type: AddressType, keyHash: Data, base58: String) {
        self.type = type
        self.keyHash = keyHash
        self.stringValue = base58
    }

    static func ==<T: Address>(lhs: LegacyAddress, rhs: T) -> Bool {
        guard let rhs = rhs as? LegacyAddress else {
            return false
        }
        return lhs.type == rhs.type && lhs.keyHash == rhs.keyHash
    }
}
