class RestoreKeyConverterChain : IRestoreKeyConverter {

    var converters = [IRestoreKeyConverter]()

    func add(converter: IRestoreKeyConverter) {
        converters.append(converter)
    }

    func keysForApiRestore(publicKey: PublicKey) -> [String] {
        var keys = [String]()
        for converter in converters {
            keys.append(contentsOf: converter.keysForApiRestore(publicKey: publicKey))
        }

        return keys.unique
    }

    func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        var keys = [Data]()
        for converter in converters {
            keys.append(contentsOf: converter.bloomFilterElements(publicKey: publicKey))
        }

        return keys.unique
    }

}

public class Bip44RestoreKeyConverter {

    let addressConverter: IAddressConverter

    public init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip44RestoreKeyConverter : IRestoreKeyConverter {

    public func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let legacyAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2pkh).stringValue

        return [legacyAddress].compactMap { $0 }
    }

    public func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        [publicKey.keyHash, publicKey.raw]
    }

}

public class Bip49RestoreKeyConverter {

    let addressConverter: IAddressConverter

    public init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip49RestoreKeyConverter : IRestoreKeyConverter {

    public func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let wpkhShAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2wpkhSh).stringValue

        return [wpkhShAddress].compactMap { $0 }
    }

    public func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        [publicKey.scriptHashForP2WPKH]
    }

}

public class Bip84RestoreKeyConverter {

    let addressConverter: IAddressConverter

    public init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip84RestoreKeyConverter : IRestoreKeyConverter {

    public func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let segwitAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2wpkh).stringValue

        return [segwitAddress].compactMap { $0 }
    }

    public func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        [publicKey.keyHash]
    }

}

public class KeyHashRestoreKeyConverter : IRestoreKeyConverter {

    public init() {}

    public func keysForApiRestore(publicKey: PublicKey) -> [String] {
        [publicKey.keyHash.hex]
    }

    public func bloomFilterElements(publicKey: PublicKey) -> [Data] {
        [publicKey.keyHash]
    }

}
