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

    func convert(keyHash: Data, type: ScriptType) throws -> String {
        let version: UInt8
        switch type {
            case .p2pkh, .p2pk: version = network.pubKeyHash
            case .p2sh: version = network.scriptHash
            case .p2wsh: version = network.scriptHash
            default: throw ConversionError.unknownAddressType
        }
        var withVersion = (Data([version])) + keyHash
        let doubleSHA256 = Crypto.sha256sha256(withVersion)
        let checksum = doubleSHA256.prefix(4)
        withVersion += checksum
        return Base58.encode(withVersion)
    }

    func convert(address: String) throws -> Data {
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
        return hex[1..<hex.count - 4]
    }

}
