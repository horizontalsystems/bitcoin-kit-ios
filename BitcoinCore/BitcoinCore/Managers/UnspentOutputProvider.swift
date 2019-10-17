class UnspentOutputProvider {
    let storage: IStorage
    let pluginManager: IPluginManager
    let confirmationsThreshold: Int

    private var confirmedUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0

        // Output must have a public key, that is, must belong to the user
        return storage.unspentOutputs()
                .filter({ unspentOutput in
                    // If a transaction is an outgoing transaction, then it can be used
                    // even if it's not included in a block yet
                    if unspentOutput.transaction.isOutgoing {
                        return true
                    }

                    // If a transaction is an incoming transaction, then it can be used
                    // only if it's included in a block and has enough number of confirmations
                    guard let blockHeight = unspentOutput.blockHeight else {
                        return false
                    }

                    return blockHeight <= lastBlockHeight - confirmationsThreshold + 1
                })
    }

    private var unspendableUtxo: [UnspentOutput] {
        confirmedUtxo.filter { !pluginManager.isSpendable(unspentOutput: $0) }
    }

    init(storage: IStorage, pluginManager: IPluginManager, confirmationsThreshold: Int) {
        self.storage = storage
        self.pluginManager = pluginManager
        self.confirmationsThreshold = confirmationsThreshold
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {

    var spendableUtxo: [UnspentOutput] {
        confirmedUtxo.filter { pluginManager.isSpendable(unspentOutput: $0) }
    }

}

extension UnspentOutputProvider: IBalanceProvider {

    var balanceInfo: BalanceInfo {
        let spendable =  spendableUtxo.map { $0.output.value }.reduce(0, +)
        let unspendable = unspendableUtxo.map { $0.output.value }.reduce(0, +)

        return BalanceInfo(spendable: spendable, unspendable: unspendable)
    }

}
