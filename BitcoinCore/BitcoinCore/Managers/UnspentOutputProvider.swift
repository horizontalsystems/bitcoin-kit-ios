class UnspentOutputProvider {
    let storage: IStorage
    let confirmationsThreshold: Int

    init(storage: IStorage, confirmationsThreshold: Int) {
        self.storage = storage
        self.confirmationsThreshold = confirmationsThreshold
    }
}

extension UnspentOutputProvider: IUnspentOutputProvider {

    var allUnspentOutputs: [UnspentOutput] {
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

}