class AddressConverterChain: IAddressConverter {
    private var concreteConverters = [IAddressConverter]()

    func prepend(addressConverter: IAddressConverter) {
        concreteConverters.insert(addressConverter, at: 0)
    }

    func convert(address: String) throws -> Address {
        var lastError: Error?

        for converter in concreteConverters {
            do {
                let converted = try converter.convert(address: address)
                return converted
            } catch {
                lastError = error
            }
        }

        throw lastError!
    }

    func convert(keyHash: Data, type: ScriptType) throws -> Address {
        var lastError: Error?

        for converter in concreteConverters {
            do {
                let converted = try converter.convert(keyHash: keyHash, type: type)
                return converted
            } catch {
                lastError = error
            }
        }

        throw lastError!
    }

}
