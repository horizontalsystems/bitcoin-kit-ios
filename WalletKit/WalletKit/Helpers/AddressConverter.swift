import Foundation

class AddressConverter {
    enum ConversionError: Error {
        case invalidChecksum
        case invalidAddressLength
        case unknownAddressType
        case wrongAddressPrefix
    }

    let network: NetworkProtocol

    init(network: NetworkProtocol) {
        self.network = network
    }

    func convert(keyHash: Data, type: ScriptType) throws -> Address {
        let version: UInt8
        let addressType: AddressType
        switch type {
            case .p2pkh, .p2pk, .p2wkh:
                version = network.pubKeyHash
                addressType = .pubKeyHash
            case .p2sh, .p2wsh:
                version = network.scriptHash
                addressType = .scriptHash
            default: throw ConversionError.unknownAddressType
        }
        var withVersion = (Data([version])) + keyHash
        let doubleSHA256 = Crypto.sha256sha256(withVersion)
        let checksum = doubleSHA256.prefix(4)
        withVersion += checksum
        let base58 = Base58.encode(withVersion)
        return Address(type: addressType, keyHash: keyHash, base58: base58)
    }

   func convert(address: String) throws -> Address {
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
        let hex = Base58.decode(address)
        let givenChecksum = hex.suffix(4)
        let doubleSHA256 = Crypto.sha256sha256(hex.prefix(hex.count - 4))
        let actualChecksum = doubleSHA256.prefix(4)
        guard givenChecksum == actualChecksum else {
            throw ConversionError.invalidChecksum
        }

        let type: AddressType
        switch hex[0] {
            case network.scriptHash: type = .scriptHash
            default: type = .pubKeyHash
        }
        let keyHash = hex.dropFirst().dropLast(4)
        return Address(type: type, keyHash: keyHash, base58: address)
    }

}
