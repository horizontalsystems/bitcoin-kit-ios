import BitcoinCore

class ConfirmedUnspentOutputProvider {
    let storage: IDashStorage
    let confirmationsThreshold: Int

    init(storage: IDashStorage, confirmationsThreshold: Int) {
        self.storage = storage
        self.confirmationsThreshold = confirmationsThreshold
    }
}


extension ConfirmedUnspentOutputProvider: IUnspentOutputProvider {

    var spendableUtxo: [UnspentOutput] {
        let lastBlockHeight = storage.lastBlock?.height ?? 0

        // Output must have a public key, that is, must belong to the user
        return storage.unspentOutputs()
                .filter({ isOutputConfirmed(unspentOutput: $0, lastBlockHeight: lastBlockHeight) })
    }

    private func isOutputConfirmed(unspentOutput: UnspentOutput, lastBlockHeight: Int) -> Bool {
        guard let blockHeight = unspentOutput.blockHeight else {
            return false
        }

        return blockHeight <= lastBlockHeight - confirmationsThreshold + 1
    }

}
