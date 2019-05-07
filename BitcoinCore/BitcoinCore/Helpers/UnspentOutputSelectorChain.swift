class UnspentOutputSelectorChain: IUnspentOutputSelector {
    var concreteSelectors = [IUnspentOutputSelector]()

    func select(value: Int, feeRate: Int, outputScriptType: ScriptType, changeType: ScriptType, senderPay: Bool) throws -> SelectedUnspentOutputInfo {
        var errors = [Error]()

        for selector in concreteSelectors {
            do {
                return try selector.select(value: value, feeRate: feeRate, outputScriptType: outputScriptType, changeType: changeType, senderPay: senderPay)
            } catch {
                errors.append(error)
            }
        }

        throw BitcoinCoreErrors.UnspentOutputSelectionErrors(errors: errors)
    }

    func prepend(unspentOutputSelector: IUnspentOutputSelector) {
        concreteSelectors.insert(unspentOutputSelector, at: 0)
    }

}
