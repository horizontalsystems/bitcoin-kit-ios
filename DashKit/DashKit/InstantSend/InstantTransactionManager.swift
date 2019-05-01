import BitcoinCore

class InstantTransactionManager {

    enum InstantSendHandleError: Error {
        case instantTransactionNotExist
    }

    private var storage: IDashStorage
    private var instantSendFactory: IInstantSendFactory
    private let transactionLockVoteValidator: ITransactionLockVoteValidator

    init(storage: IDashStorage, instantSendFactory: IInstantSendFactory, transactionLockVoteValidator: ITransactionLockVoteValidator) {
        self.storage = storage
        self.instantSendFactory = instantSendFactory
        self.transactionLockVoteValidator = transactionLockVoteValidator
    }

    private func makeInputs(for txHash: Data, inputs: [Input]) -> [InstantTransactionInput] {
        var instantInputs = [InstantTransactionInput]()
        for input in inputs {
            let instantInput = instantSendFactory.instantTransactionInput(txHash: txHash, inputTxHash: input.previousOutputTxHash, voteCount: 0, blockHeight: nil)

            storage.add(instantTransactionInput: instantInput)
            instantInputs.append(instantInput)
        }
        return instantInputs
    }

}

extension InstantTransactionManager: IInstantTransactionManager {

    func instantTransactionInputs(for txHash: Data, instantTransaction: FullTransaction?) -> [InstantTransactionInput] {
        // check if inputs already created
        let inputs = storage.instantTransactionInputs(for: txHash)
        if !inputs.isEmpty {
            return inputs
        }

        // if not check coming ix
        if let transaction = instantTransaction {
            return makeInputs(for: txHash, inputs: transaction.inputs)
        }

        // if we can't get inputs and ix is null, try get tx inputs from db
        return makeInputs(for: txHash, inputs: storage.inputs(transactionHash: txHash))
    }

    func increaseVoteCount(for inputTxHash: Data) {
        guard let input = storage.instantTransactionInput(for: inputTxHash) else {
            // can't find input for this vote. Ignore it
            return
        }
        let increasedInput = instantSendFactory.instantTransactionInput(txHash: input.txHash, inputTxHash: input.inputTxHash, voteCount: input.voteCount + 1, blockHeight: input.blockHeight)

        storage.add(instantTransactionInput: increasedInput)
    }

    func isTransactionInstant(txHash: Data) -> Bool {
        let inputs = storage.instantTransactionInputs(for: txHash)
        guard !inputs.isEmpty else {
            return false
        }

        return inputs.filter { $0.voteCount < InstantSend.requiredVoteCount }.isEmpty
    }

}
