struct PeerTaskData {
    let peer: IPeer
    let task: PeerTask
}

class InstantSend {
    var successor: IPeerTaskHandler?

    private let transactionSyncer: ITransactionSyncer

    init(transactionSyncer: ITransactionSyncer) {
        self.transactionSyncer = transactionSyncer
    }

}

extension InstantSend: IPeerTaskHandler {
    func set(successor: IPeerTaskHandler) -> IPeerTaskHandler {
        self.successor = successor
        return self
    }

    func attach(to element: IPeerTaskHandler) -> IPeerTaskHandler {
        return element.set(successor: self)
    }

    func handleCompletedTask(peer: IPeer, task: PeerTask) {
        switch task {
        case let task as RequestTransactionsTask: transactionSyncer.handle(transactions: task.transactions)
        case let task as RequestTransactionLockVotesTask: task.transactionLockVotes.forEach { print("AAAAAAA got tx votes : \($0.hash.reversedHex)") }
        default: successor?.handleCompletedTask(peer: peer, task: task)
        }
    }

}

extension InstantSend: IInventoryItemsHandler {

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        var transactionLockRequests = [Data]()
        var transactionLockVotes = [Data]()

        inventoryItems.forEach { item in
            switch item.type {
            case InventoryType.msgTxLockRequest.rawValue: transactionLockRequests.append(item.hash)
            case InventoryType.msgTxLockVote.rawValue: transactionLockVotes.append(item.hash)
            default: break
            }
        }
        if !transactionLockRequests.isEmpty {
            peer.add(task: RequestTransactionLockRequestsTask(hashes: transactionLockRequests))
        }
        if !transactionLockVotes.isEmpty {
            peer.add(task: RequestTransactionLockVotesTask(hashes: transactionLockVotes))
        }
    }

}
