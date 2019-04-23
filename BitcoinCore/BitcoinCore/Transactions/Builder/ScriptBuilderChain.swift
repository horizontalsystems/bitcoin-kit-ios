class ScriptBuilderChain: IScriptBuilder {
    private var concreteBuilders = [IScriptBuilder]()

    func prepend(scriptBuilder: IScriptBuilder) {
        concreteBuilders.insert(scriptBuilder, at: 0)
    }

    func lockingScript(for address: Address) throws -> Data {
        var errors = [Error]()

        for builder in concreteBuilders {
            do {
                let converted = try builder.lockingScript(for: address)
                return converted
            } catch {
                errors.append(error)
            }
        }

        throw BitcoinCoreErrors.AddressConversionErrors(errors: errors)
    }

}
