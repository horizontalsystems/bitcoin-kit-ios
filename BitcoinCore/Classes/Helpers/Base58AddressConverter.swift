import OpenSslKit

public class Base58AddressConverter: IAddressConverter {
    private static let checkSumLength = 4
    private let addressVersion: UInt8
    private let addressScriptVersion: UInt8

    public init(addressVersion: UInt8, addressScriptVersion: UInt8) {
        self.addressVersion = addressVersion
        self.addressScriptVersion = addressScriptVersion
    }

    public func convert(address: String) throws -> Address {
        // check length of address to avoid wrong converting
        guard address.count >= 26 && address.count <= 35 else {
            throw BitcoinCoreErrors.AddressConversion.invalidAddressLength
        }

        let hex = Base58.decode(address)
        // check decoded length. Must be 1(version) + 20(KeyHash) + 4(CheckSum)
        if hex.count != Base58AddressConverter.checkSumLength + 20 + 1 {
            throw BitcoinCoreErrors.AddressConversion.invalidAddressLength
        }
        let givenChecksum = hex.suffix(Base58AddressConverter.checkSumLength)
        let doubleSHA256 = Kit.sha256sha256(hex.prefix(hex.count - Base58AddressConverter.checkSumLength))
        let actualChecksum = doubleSHA256.prefix(Base58AddressConverter.checkSumLength)
        guard givenChecksum == actualChecksum else {
            throw BitcoinCoreErrors.AddressConversion.invalidChecksum
        }

        let type: AddressType
        switch hex[0] {
            case addressVersion: type = AddressType.pubKeyHash
            case addressScriptVersion: type = AddressType.scriptHash
            default: throw BitcoinCoreErrors.AddressConversion.wrongAddressPrefix
        }

        let keyHash = hex.dropFirst().dropLast(4)
        return LegacyAddress(type: type, keyHash: keyHash, base58: address)
    }

    public func convert(keyHash: Data, type: ScriptType) throws -> Address {
        let version: UInt8
        let addressType: AddressType

        switch type {
            case .p2pkh, .p2pk:
                version = addressVersion
                addressType = AddressType.pubKeyHash
            case .p2sh, .p2wpkhSh:
                version = addressScriptVersion
                addressType = AddressType.scriptHash
            default: throw BitcoinCoreErrors.AddressConversion.unknownAddressType
        }

        var withVersion = (Data([version])) + keyHash
        let doubleSHA256 = Kit.sha256sha256(withVersion)
        let checksum = doubleSHA256.prefix(4)
        withVersion += checksum
        let base58 = Base58.encode(withVersion)
        return LegacyAddress(type: addressType, keyHash: keyHash, base58: base58)
    }

    public func convert(publicKey: PublicKey, type: ScriptType) throws -> Address {
        let keyHash = type == .p2wpkhSh ? publicKey.scriptHashForP2WPKH : publicKey.keyHash
        return try convert(keyHash: keyHash, type: type)
    }

}
