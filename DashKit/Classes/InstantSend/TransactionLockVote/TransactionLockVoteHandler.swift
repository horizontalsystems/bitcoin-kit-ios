import BitcoinCore
import HsToolKit

class TransactionLockVoteHandler: ITransactionLockVoteHandler {
    private let requiredVoteCount: Int

    private let instantTransactionManager: IInstantTransactionManager
    private let lockVoteManager: ITransactionLockVoteManager

    public weak var delegate: IInstantTransactionDelegate?
    private let logger: Logger?

    init(instantTransactionManager: IInstantTransactionManager, lockVoteManager: ITransactionLockVoteManager, requiredVoteCount: Int = 6, logger: Logger? = nil) {
        self.instantTransactionManager = instantTransactionManager
        self.lockVoteManager = lockVoteManager
        self.logger = logger

        self.requiredVoteCount = requiredVoteCount
    }

    public func handle(transaction: FullTransaction) {
        // check transaction already not in instant
        guard !instantTransactionManager.isTransactionInstant(txHash: transaction.header.dataHash) else {
            return
        }
        // prepare instant inputs for ix
        let inputs = instantTransactionManager.instantTransactionInputs(for: transaction.header.dataHash, instantTransaction: transaction)

        // poll relayed lock votes to update inputs
        let relayedVotes = lockVoteManager.takeRelayedLockVotes(for: transaction.header.dataHash)
        relayedVotes.forEach { vote in
            handle(lockVote: vote, instantInputs: inputs)
        }
    }

    public func handle(lockVote: TransactionLockVoteMessage) {
        // check transaction already not in instant
        guard !instantTransactionManager.isTransactionInstant(txHash: lockVote.txHash) else {
            return
        }
        guard !lockVoteManager.processed(lvHash: lockVote.hash) else {
            return
        }
        let inputs = instantTransactionManager.instantTransactionInputs(for: lockVote.txHash, instantTransaction: nil)
        guard !inputs.isEmpty else {
            lockVoteManager.add(relayed: lockVote)
            return
        }
        handle(lockVote: lockVote, instantInputs: inputs)

    }

    private func handle(lockVote: TransactionLockVoteMessage, instantInputs: [InstantTransactionInput]) {
        lockVoteManager.add(checked: lockVote)
        // ignore votes for inputs which already has 6 votes
        guard let input = instantInputs.first(where: { $0.inputTxHash == lockVote.outpoint.txHash }), input.voteCount < requiredVoteCount else {
            return
        }

        do {
            try lockVoteManager.validate(lockVote: lockVote)
            try instantTransactionManager.updateInput(for: lockVote.outpoint.txHash, transactionInputs: instantInputs)

            let instant = instantTransactionManager.isTransactionInstant(txHash: lockVote.txHash)
            if instant {
                delegate?.onUpdateInstant(transactionHash: lockVote.txHash)
            }
        } catch {
            logger?.error(error)
        }
    }

}

