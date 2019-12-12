import BitcoinCore

public class CashAddress: Address, Equatable {
    public let type: AddressType
    public let keyHash: Data
    public let stringValue: String
    public let version: UInt8

    public var scriptType: ScriptType {
        switch type {
        case .pubKeyHash: return .p2pkh
        case .scriptHash: return .p2sh
        }
    }

    public var lockingScript: Data {
        switch type {
        case .pubKeyHash: return OpCode.p2pkhStart + OpCode.push(keyHash) + OpCode.p2pkhFinish
        case .scriptHash: return OpCode.p2shStart + OpCode.push(keyHash) + OpCode.p2shFinish
        }
    }

    public init(type: AddressType, keyHash: Data, cashAddrBech32: String, version: UInt8) {
        self.type = type
        self.keyHash = keyHash
        self.stringValue = cashAddrBech32
        self.version = version
    }

    static public func ==<T: Address>(lhs: CashAddress, rhs: T) -> Bool {
        guard let rhs = rhs as? CashAddress else {
            return false
        }
        return lhs.type == rhs.type && lhs.keyHash == rhs.keyHash && lhs.version == rhs.version
    }

}
