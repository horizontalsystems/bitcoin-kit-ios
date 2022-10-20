@testable import BitcoinCore

public class SegWitAddress: Address, Equatable {
    public let type: AddressType
    public let keyHash: Data
    public let stringValue: String
    public let version: UInt8

    public var scriptType: ScriptType {
        switch type {
        case .pubKeyHash: return .p2wpkh
        case .scriptHash: return .p2wsh
        }
    }

    public var lockingScript: Data {
        // Data[0] - version byte, Data[1] - push keyHash
        OpCode.push(Int(version)) + OpCode.push(keyHash)
    }

    public init(type: AddressType, keyHash: Data, bech32: String, version: UInt8) {
        self.type = type
        self.keyHash = keyHash
        self.stringValue = bech32
        self.version = version
    }

    static public func ==<T: Address>(lhs: SegWitAddress, rhs: T) -> Bool {
        guard let rhs = rhs as? SegWitAddress else {
            return false
        }
        return lhs.type == rhs.type && lhs.keyHash == rhs.keyHash && lhs.version == rhs.version
    }
}
