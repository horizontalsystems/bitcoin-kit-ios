import BitcoinCore
import HsToolKit

enum DashInventoryType: Int32 { case msgTxLockRequest = 4, msgTxLockVote = 5, msgIsLock = 30 }

class InstantSend {
    static let requiredVoteCount = 6
    let dispatchQueue: DispatchQueue

    private let transactionSyncer: IDashTransactionSyncer
    private let transactionLockVoteHandler: ITransactionLockVoteHandler
    private let instantSendLockHandler: IInstantSendLockHandler
    private let logger: Logger?

    init(transactionSyncer: IDashTransactionSyncer, transactionLockVoteHandler: ITransactionLockVoteHandler, instantSendLockHandler: IInstantSendLockHandler, dispatchQueue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.dash-kit.instant-send", qos: .userInitiated), logger: Logger? = nil) {
        self.transactionSyncer = transactionSyncer
        self.transactionLockVoteHandler = transactionLockVoteHandler
        self.instantSendLockHandler = instantSendLockHandler
        self.dispatchQueue = dispatchQueue

        self.logger = logger
    }

    public func handle(insertedTxHash: Data) {
        instantSendLockHandler.handle(transactionHash: insertedTxHash)
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
        transactionSyncer.handleRelayed(transactions: transactions)

        for transaction in transactions {
            transactionLockVoteHandler.handle(transaction: transaction)
        }
    }

    private func handle(transactionLockVotes: [TransactionLockVoteMessage]) {
        for lockVote in transactionLockVotes {
            transactionLockVoteHandler.handle(lockVote: lockVote)
        }
    }

    private func handle(llmqInstantSendLocks: [ISLockMessage]) {
        for isLock in llmqInstantSendLocks {
            instantSendLockHandler.handle(isLock: isLock)
        }
    }

}

extension InstantSend: IInventoryItemsHandler {

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        var transactionLockRequests = [Data]()
        var transactionLockVotes = [Data]()
        var isLocks = [Data]()

        inventoryItems.forEach { item in
            switch item.type {
            case DashInventoryType.msgTxLockRequest.rawValue:
                transactionLockRequests.append(item.hash)

            case DashInventoryType.msgTxLockVote.rawValue:
                transactionLockVotes.append(item.hash)

            case DashInventoryType.msgIsLock.rawValue:
                isLocks.append(item.hash)

            default: break
            }
        }
        if !transactionLockRequests.isEmpty {
            peer.add(task: RequestTransactionLockRequestsTask(hashes: transactionLockRequests))
        }
        if !transactionLockVotes.isEmpty {
            peer.add(task: RequestTransactionLockVotesTask(hashes: transactionLockVotes))
        }
        if !isLocks.isEmpty {
            peer.add(task: RequestLlmqInstantLocksTask(hashes: isLocks))
        }
    }

}
