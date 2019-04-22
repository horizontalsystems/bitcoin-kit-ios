class InstantSendFactory: IInstantSendFactory {

    func instantTransactionInput(txHash: Data, inputTxHash: Data, voteCount: Int, blockHeight: Int?) -> InstantTransactionInput {
        let timeCreated = Int(Date().timeIntervalSince1970)

        return InstantTransactionInput(txHash: txHash, inputTxHash: inputTxHash, timeCreated: timeCreated, voteCount: voteCount, blockHeight: blockHeight)
    }

}
