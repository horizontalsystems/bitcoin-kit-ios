class TransactionLinker: ITransactionLinker {

    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func handle(transaction: FullTransaction) {
        for input in transaction.inputs {
            guard let previousOutput = storage.previousOutput(ofInput: input), previousOutput.publicKeyPath != nil else {
                continue
            }

            transaction.header.isMine = true
            transaction.header.isOutgoing = true
        }
    }

}
