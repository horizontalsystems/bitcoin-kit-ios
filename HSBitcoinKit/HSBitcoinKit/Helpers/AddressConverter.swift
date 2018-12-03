import HSCryptoKit

class AddressConverter {
    enum ConversionError: Error {
        case invalidChecksum
        case invalidAddressLength
        case unknownAddressType
        case wrongAddressPrefix
    }

    let network: INetwork
    let bech32AddressConverter: IBech32AddressConverter

    init(network: INetwork, bech32AddressConverter: IBech32AddressConverter) {
        self.bech32AddressConverter = bech32AddressConverter
        self.network = network
    }

}

extension AddressConverter: IAddressConverter {

    func convert(keyHash: Data, type: ScriptType) throws -> Address {
        if let address = try? bech32AddressConverter.convert(prefix: network.bech32PrefixPattern, keyData: keyHash, scriptType: type) {
            return address
        }
        let version: UInt8
        let addressType: AddressType
        switch type {
        case .p2pkh, .p2pk:
            version = network.pubKeyHash
            addressType = .pubKeyHash
        case .p2sh:
            version = network.scriptHash
            addressType = .scriptHash
        default: throw ConversionError.unknownAddressType
        }
        return convertToLegacy(keyHash: keyHash, version: version, addressType: addressType)
    }

    func convertToLegacy(keyHash: Data, version: UInt8, addressType: AddressType) -> LegacyAddress {
        var withVersion = (Data([version])) + keyHash
        let doubleSHA256 = CryptoKit.sha256sha256(withVersion)
        let checksum = doubleSHA256.prefix(4)
        withVersion += checksum
        let base58 = Base58.encode(withVersion)
        return LegacyAddress(type: addressType, keyHash: keyHash, base58: base58)
    }

    func convert(address: String) throws -> Address {
        if let address = try? bech32AddressConverter.convert(prefix: network.bech32PrefixPattern, address: address) {
            return address
        }
        guard address.count >= 34 && address.count <= 55 else {
            throw ConversionError.invalidAddressLength
        }
        let pattern = ["^\(network.scriptPrefixPattern)", "^\(network.pubKeyPrefixPattern)"]
        var unknownPrefix = true
        pattern.forEach { pattern in
            if let regex = try? NSRegularExpression(pattern: pattern), !regex.matches(in: address, range: NSRange(location: 0, length: address.count)).isEmpty {
                unknownPrefix = false
            }
        }
        if unknownPrefix {
            throw ConversionError.wrongAddressPrefix
        }
        let suffixLength = 4

        let hex = Base58.decode(address)
        if hex.count < suffixLength {
            throw ConversionError.invalidAddressLength
        }
        let givenChecksum = hex.suffix(suffixLength)
        let doubleSHA256 = CryptoKit.sha256sha256(hex.prefix(hex.count - suffixLength))
        let actualChecksum = doubleSHA256.prefix(suffixLength)
        guard givenChecksum == actualChecksum else {
            throw ConversionError.invalidChecksum
        }

        let type: AddressType
        switch hex[0] {
        case network.scriptHash: type = .scriptHash
        default: type = .pubKeyHash
        }
        let keyHash = hex.dropFirst().dropLast(4)
        return LegacyAddress(type: type, keyHash: keyHash, base58: address)
    }

}
