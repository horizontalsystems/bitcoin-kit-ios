import Foundation

class SegWitBech32AddressConverter: IBech32AddressConverter {
    private let scriptConverter: IScriptConverter

    init(scriptConverter: IScriptConverter) {
        self.scriptConverter = scriptConverter
    }

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

    func convert(prefix: String, keyData: Data, scriptType: ScriptType) throws -> Address {
        let script = try scriptConverter.decode(data: keyData)
        guard script.chunks.count == 2,
              let versionCode = script.chunks.first?.opCode,
              let versionByte = OpCode.value(fromPush: versionCode),
              let keyHash = script.chunks.last?.data else {
            throw AddressConverter.ConversionError.invalidAddressLength
        }
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
