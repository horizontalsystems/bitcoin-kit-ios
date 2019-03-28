struct PeerTaskData {
    let peer: IPeer
    let task: PeerTask
}

class InstantSend {
    var successor: IPeerTaskHandler?

    private let instantTransactionManager: IInstantTransactionManager

    init(instantTransactionManager: IInstantTransactionManager) {
        self.instantTransactionManager = instantTransactionManager
    }

}

extension InstantSend: IPeerTaskHandler {
    @discardableResult func set(successor: IPeerTaskHandler) -> IPeerTaskHandler {
        self.successor = successor
        return self
    }

    @discardableResult func attach(to element: IPeerTaskHandler) -> IPeerTaskHandler {
        return element.set(successor: self)
    }

    func handleCompletedTask(peer: IPeer, task: PeerTask) {
        switch task {
        case let task as RequestTransactionLockRequestsTask:
            print("handle RequestTransactionLock RequestsTask")
            instantTransactionManager.handle(transactions: task.transactions)
        case let task as RequestTransactionLockVotesTask: task.transactionLockVotes.forEach {
            print("handle RequestTransactionLockVotes Task")
            try? instantTransactionManager.handle(lockVote: $0)
            // что то надо делать
            // ищем транзакцию среди наших, иначе игнор
            // проверям что quore мастернода есть и он дуйствующий иначе игнор
            // Нужен новый параметр

            print("AAAAAAA got tx votes : \($0.hash.reversedHex) \($0.outpoint.txHash.hex)-\($0.outpoint.vout)") 
        }
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
            case InventoryType.msgTxLockRequest.rawValue:
                transactionLockRequests.append(item.hash)
            case InventoryType.msgTxLockVote.rawValue:
                transactionLockVotes.append(item.hash)
            default: break
            }
        }
        if !transactionLockRequests.isEmpty {
            print("add task RequestTransactionLock RequestsTask")

            peer.add(task: RequestTransactionLockRequestsTask(hashes: transactionLockRequests))
        }
        if !transactionLockVotes.isEmpty {
            print("add task RequestTransactionLockVotes Task")

            peer.add(task: RequestTransactionLockVotesTask(hashes: transactionLockVotes))
        }
    }

}
