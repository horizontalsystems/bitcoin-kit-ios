import Foundation

class SegWitBech32AddressConverter: Bech32AddressConverter {

    func convert(prefix: String, address: String) throws -> Address {
        if let segWitData = try? SegWitBech32.decode(hrp: prefix, addr: address) {
            var type: AddressType = .pubKeyHash
            if segWitData.version == 0 {
                switch segWitData.program.count {
                    case 32: type = .scriptHash
                    default: break
                }
            }
            return SegWitAddress(type: type, keyHash: segWitData.program, bech32: address, version: segWitData.version)
        }
        throw AddressConverter.ConversionError.unknownAddressType
    }

    //TODO: SegWit address must use WitnessProgramm in keyHash, not pubKeyHash or scriptHash. Bacause in versionByte placed in first byte.
    func convert(prefix: String, keyHash: Data, scriptType: ScriptType) throws -> Address {
        let versionByte: UInt8 = 0  // only 0 is support now
        let addressType: AddressType
        switch scriptType {
            case .p2wpkh:
                addressType = AddressType.pubKeyHash
            case .p2wsh:
                addressType = AddressType.scriptHash
            default: throw AddressConverter.ConversionError.unknownAddressType
        }
        let bech32 = try SegWitBech32.encode(hrp: prefix, version: versionByte, program: keyHash)
        return SegWitAddress(type: addressType, keyHash: keyHash, bech32: bech32, version: versionByte)
    }

}
