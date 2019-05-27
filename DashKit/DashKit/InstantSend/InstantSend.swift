import BitcoinCore

enum DashInventoryType: Int32 { case msgTxLockRequest = 4, msgTxLockVote = 5, msgIsLock = 30 }

class InstantSend {
    static let requiredVoteCount = 6
    let dispatchQueue: DispatchQueue

    private let transactionSyncer: IDashTransactionSyncer
    private let instantTransactionManager: IInstantTransactionManager
    private let lockVoteManager: ITransactionLockVoteManager
    private let instantSendLockValidator: IInstantSendLockValidator

    public weak var delegate: IInstantTransactionDelegate?

    private let logger: Logger?

    init(transactionSyncer: IDashTransactionSyncer, lockVoteManager: ITransactionLockVoteManager, instantSendLockValidator: IInstantSendLockValidator, instantTransactionManager: IInstantTransactionManager, dispatchQueue: DispatchQueue = DispatchQueue(label: "DashInstantSend", qos: .userInitiated), logger: Logger? = nil) {
        self.transactionSyncer = transactionSyncer
        self.lockVoteManager = lockVoteManager
        self.instantSendLockValidator = instantSendLockValidator
        self.instantTransactionManager = instantTransactionManager
        self.dispatchQueue = dispatchQueue

        self.logger = logger
    }

}

extension InstantSend: IPeerTaskHandler {

    public func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let task as RequestTransactionLockRequestsTask:
            dispatchQueue.async {
                self.handle(transactions: task.transactions)
            }
            return true

        case let task as RequestTransactionLockVotesTask:
            dispatchQueue.async {
                self.handle(transactionLockVotes: task.transactionLockVotes)
            }
            return true

        case let task as RequestLlmqInstantLocksTask:
            dispatchQueue.async {
                self.handle(llmqInstantSendLocks: task.llmqInstantLocks)
            }
            return true

        default: return false
        }
    }

    private func handle(transactions: [FullTransaction]) {
        transactionSyncer.handle(transactions: transactions)

        for transaction in transactions {
            // check transaction already not in instant
            guard !instantTransactionManager.isTransactionInstant(txHash: transaction.header.dataHash) else {
                continue
            }
            // prepare instant inputs for ix
            let inputs = instantTransactionManager.instantTransactionInputs(for: transaction.header.dataHash, instantTransaction: transaction)

            // poll relayed lock votes to update inputs
            let relayedVotes = lockVoteManager.takeRelayedLockVotes(for: transaction.header.dataHash)
            relayedVotes.forEach { vote in
                handle(lockVote: vote, instantInputs: inputs)
            }
        }
    }

    private func handle(transactionLockVotes: [TransactionLockVoteMessage]) {
        for vote in transactionLockVotes {
            // check transaction already not in instant
            guard !instantTransactionManager.isTransactionInstant(txHash: vote.txHash) else {
                continue
            }
            guard !lockVoteManager.processed(lvHash: vote.hash) else {
                continue
            }
            let inputs = instantTransactionManager.instantTransactionInputs(for: vote.txHash, instantTransaction: nil)
            guard !inputs.isEmpty else {
                lockVoteManager.add(relayed: vote)
                continue
            }
            handle(lockVote: vote, instantInputs: inputs)
        }
    }

    private func handle(lockVote: TransactionLockVoteMessage, instantInputs: [InstantTransactionInput]) {
        lockVoteManager.add(checked: lockVote)
        // ignore votes for inputs which already has 6 votes
        guard let input = instantInputs.first(where: { $0.inputTxHash == lockVote.outpoint.txHash }), input.voteCount < InstantSend.requiredVoteCount else {
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

    private func handle(llmqInstantSendLocks: [ISLockMessage]) {
        for isLock in llmqInstantSendLocks {
            // check transaction already not in instant
            guard !instantTransactionManager.isTransactionInstant(txHash: isLock.txHash) else {
                continue
            }
            // do nothing if tx doesn't exist
            guard instantTransactionManager.isTransactionExists(txHash: isLock.txHash) else {
                continue
            }
            // validation
            do {
                try instantSendLockValidator.validate(isLock: isLock)

                instantTransactionManager.makeInstant(txHash: isLock.txHash)
                delegate?.onUpdateInstant(transactionHash: isLock.txHash)
            } catch {
                logger?.error(error)
            }
        }
    }

}

extension InstantSend: IInventoryItemsHandler {

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        var transactionLockRequests = [Data]()
        var transactionLockVotes = [Data]()
        var llmqInstantLocks = [Data]()

        inventoryItems.forEach { item in
            switch item.type {
            case DashInventoryType.msgTxLockRequest.rawValue:
                transactionLockRequests.append(item.hash)

            case DashInventoryType.msgTxLockVote.rawValue:
                transactionLockVotes.append(item.hash)

            case DashInventoryType.msgIsLock.rawValue:
                llmqInstantLocks.append(item.hash)

            default: break
            }
        }
        if !transactionLockRequests.isEmpty {
            peer.add(task: RequestTransactionLockRequestsTask(hashes: transactionLockRequests))
        }
        if !transactionLockVotes.isEmpty {
            peer.add(task: RequestTransactionLockVotesTask(hashes: transactionLockVotes))
        }
        if !llmqInstantLocks.isEmpty {
            peer.add(task: RequestLlmqInstantLocksTask(hashes: llmqInstantLocks))
        }
    }

}
