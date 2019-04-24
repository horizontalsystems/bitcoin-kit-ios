import BitcoinCore

class InstantTransactionManager: IInstantTransactionManager {
    static let requiredVoteCount = 6

    enum InstantSendHandleError: Error { case instantTransactionNotExist }

    private var storage: IDashStorage
    private var instantSendFactory: IInstantSendFactory
    private let transactionSyncer: ITransactionSyncer
    private let transactionLockVoteValidator: ITransactionLockVoteValidator

    init(storage: IDashStorage, instantSendFactory: IInstantSendFactory, transactionSyncer: ITransactionSyncer, transactionLockVoteValidator: ITransactionLockVoteValidator) {
        self.storage = storage
        self.instantSendFactory = instantSendFactory
        self.transactionSyncer = transactionSyncer
        self.transactionLockVoteValidator = transactionLockVoteValidator
    }

    func handle(transactions: [FullTransaction]) {
        guard !transactions.isEmpty else {
            return
        }
        transactions.forEach { transaction in
            updateInputs(for: transaction)
        }

        transactionSyncer.handle(transactions: transactions)
    }

    private func updateInputs(for transaction: FullTransaction) {
        for i in 0..<transaction.inputs.count {
            let previousOutputTxHash = transaction.inputs[i].previousOutputTxHash
            let input = instantSendFactory.instantTransactionInput(txHash: transaction.header.dataHash, inputTxHash: previousOutputTxHash, voteCount: 0, blockHeight: nil)

            storage.add(instantTransactionInput: input)
        }
    }

    func handle(lockVote: TransactionLockVoteMessage) throws {
        // validate masternode in top 10 masternodes for quorumModifier
        try transactionLockVoteValidator.validate(quorumModifierHash: lockVote.quorumModifierHash, masternodeProTxHash: lockVote.masternodeProTxHash)

        // get all vote list for transaction and check if this tx approved
        var instantTransactionInputs = storage.instantTransactionInputs(for: lockVote.txHash)

        guard let inputIndex = instantTransactionInputs.firstIndex(where: { $0.inputTxHash == lockVote.outpoint.txHash }) else {
            print("InstantSendHandleError.instantTransactionNotExist")
            throw InstantSendHandleError.instantTransactionNotExist
        }
        let input = instantTransactionInputs[inputIndex]
        if input.voteCount < InstantTransactionManager.requiredVoteCount - 1 {
            // increment vote count for unspent output
            let newInput = instantSendFactory.instantTransactionInput(txHash: input.txHash, inputTxHash: input.inputTxHash, voteCount: input.voteCount + 1, blockHeight: input.blockHeight)
            storage.add(instantTransactionInput: newInput)

            return
        }

        // remove approved input
        instantTransactionInputs.remove(at: inputIndex)

        // check all inputs is approved( has 6+ lockVote)
        var approved = true
        instantTransactionInputs.forEach { input in
            if input.voteCount < InstantTransactionManager.requiredVoteCount {
                approved = false
            }
        }

        guard approved else {
            return
        }

        //notify that transaction is Approved Instant Send!
        print("INSTANT SEND APPROVED")
    }

    func validate(lockVote: TransactionLockVoteMessage) throws {
    }

}
