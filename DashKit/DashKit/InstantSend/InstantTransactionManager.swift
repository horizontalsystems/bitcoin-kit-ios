import BitcoinCore

class InstantTransactionManager {
    private var state: IInstantTransactionState

    enum InstantSendHandleError: Error {
        case instantTransactionNotExist
    }

    private var storage: IDashStorage
    private var instantSendFactory: IInstantSendFactory

    init(storage: IDashStorage, instantSendFactory: IInstantSendFactory, instantTransactionState: IInstantTransactionState) {
        self.storage = storage
        self.instantSendFactory = instantSendFactory
        self.state = instantTransactionState

        state.instantTransactionHashes = storage.instantTransactionHashes()
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

    func updateInput(for inputTxHash: Data, transactionInputs: [InstantTransactionInput]) throws {
        var updatedInputs = transactionInputs
        guard let inputIndex = transactionInputs.firstIndex(where: { $0.inputTxHash == inputTxHash }) else {
            // can't find input for this vote. Ignore it
            throw DashKitErrors.LockVoteValidation.txInputNotFound
        }
        let input = transactionInputs[inputIndex]
        let increasedInput = instantSendFactory.instantTransactionInput(txHash: input.txHash, inputTxHash: input.inputTxHash, voteCount: input.voteCount + 1, blockHeight: input.blockHeight)
        storage.add(instantTransactionInput: increasedInput)

        updatedInputs[inputIndex] = increasedInput
        if (updatedInputs.filter { $0.voteCount < InstantSend.requiredVoteCount }).isEmpty {
            state.append(input.txHash)
            storage.add(instantTransactionHash: input.txHash)
            storage.removeInstantTransactionInputs(for: input.txHash)
        }
    }

    func isTransactionInstant(txHash: Data) -> Bool {
        return state.instantTransactionHashes.contains(txHash)
    }

    func isTransactionExists(txHash: Data) -> Bool {
        return storage.transactionExists(byHash: txHash)
    }

    func makeInstant(txHash: Data) {
        state.append(txHash)
        storage.add(instantTransactionHash: txHash)
    }

}
