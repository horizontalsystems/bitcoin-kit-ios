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

}

class Bip44RestoreKeyConverter {

    let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip44RestoreKeyConverter : IRestoreKeyConverter {

    func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let legacyAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2pkh).stringValue

        return [legacyAddress].compactMap { $0 }
    }

}

class Bip49RestoreKeyConverter {

    let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip49RestoreKeyConverter : IRestoreKeyConverter {

    func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let wpkhShAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2wpkhSh).stringValue

        return [wpkhShAddress].compactMap { $0 }
    }

}


class Bip84RestoreKeyConverter {

    let addressConverter: IAddressConverter

    init(addressConverter: IAddressConverter) {
        self.addressConverter = addressConverter
    }

}

extension Bip84RestoreKeyConverter : IRestoreKeyConverter {

    func keysForApiRestore(publicKey: PublicKey) -> [String] {
        let segwitAddress = try? addressConverter.convert(publicKey: publicKey, type: .p2wpkh).stringValue

        return [segwitAddress].compactMap { $0 }
    }

}
