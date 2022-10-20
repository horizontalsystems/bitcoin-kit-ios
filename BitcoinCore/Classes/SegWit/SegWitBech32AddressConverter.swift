public class SegWitBech32AddressConverter: IAddressConverter {
    private let prefix: String
    private let scriptConverter: IScriptConverter

    public init(prefix: String, scriptConverter: IScriptConverter) {
        self.prefix = prefix
        self.scriptConverter = scriptConverter
    }

    public func convert(address: String) throws -> Address {
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
        throw BitcoinCoreErrors.AddressConversion.unknownAddressType
    }

    public func convert(keyHash: Data, type: ScriptType) throws -> Address {
        let script = try scriptConverter.decode(data: keyHash)
        guard script.chunks.count == 2,
              let versionCode = script.chunks.first?.opCode,
              let versionByte = OpCode.value(fromPush: versionCode),
              let keyHash = script.chunks.last?.data else {
            throw BitcoinCoreErrors.AddressConversion.invalidAddressLength
        }
        let addressType: AddressType
        switch type {
            case .p2wpkh:
                addressType = AddressType.pubKeyHash
            case .p2wsh:
                addressType = AddressType.scriptHash
            default: throw BitcoinCoreErrors.AddressConversion.unknownAddressType
        }
        let bech32 = try SegWitBech32.encode(hrp: prefix, version: versionByte, program: keyHash)
        return SegWitAddress(type: addressType, keyHash: keyHash, bech32: bech32, version: versionByte)
    }

    public func convert(publicKey: PublicKey, type: ScriptType) throws -> Address {
        try convert(keyHash: OpCode.scriptWPKH(publicKey.keyHash), type: type)
    }

}
