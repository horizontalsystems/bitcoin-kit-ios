class UnspentOutputSelectorChain: IUnspentOutputSelector {
    var concreteSelectors = [IUnspentOutputSelector]()

    func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool, pluginDataOutputSize: Int) throws -> SelectedUnspentOutputInfo {
        var lastError: Error = BitcoinCoreErrors.Unexpected.unknown

        for selector in concreteSelectors {
            do {
                return try selector.select(value: value, feeRate: feeRate, outputScriptType: outputScriptType, changeType: changeType, senderPay: senderPay, pluginDataOutputSize: pluginDataOutputSize)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    func prepend(unspentOutputSelector: IUnspentOutputSelector) {
        concreteSelectors.insert(unspentOutputSelector, at: 0)
    }

}
