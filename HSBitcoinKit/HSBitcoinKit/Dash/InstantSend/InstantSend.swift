enum DashInventoryType: Int32 { case msgTxLockRequest = 4, msgTxLockVote = 5 }

class InstantSend {
    var successor: IPeerTaskHandler?

    private let instantTransactionManager: IInstantTransactionManager

    init(instantTransactionManager: IInstantTransactionManager) {
        self.instantTransactionManager = instantTransactionManager
    }

}

extension InstantSend: IPeerTaskHandler {

    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let task as RequestTransactionLockRequestsTask:
            instantTransactionManager.handle(transactions: task.transactions)
            return true

        case let task as RequestTransactionLockVotesTask: task.transactionLockVotes.forEach {
                try? instantTransactionManager.handle(lockVote: $0)
                // что то надо делать
                // ищем транзакцию среди наших, иначе игнор
                // проверям что quore мастернода есть и он дуйствующий иначе игнор
                // Нужен новый параметр

                print("AAAAAAA got tx votes : \($0.hash.reversedHex) \($0.outpoint.txHash.hex)-\($0.outpoint.vout)") 
            }
            return true

        default: return false
        }
    }

}

extension InstantSend: IInventoryItemsHandler {

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        var transactionLockRequests = [Data]()
        var transactionLockVotes = [Data]()

        inventoryItems.forEach { item in
            switch item.type {
            case DashInventoryType.msgTxLockRequest.rawValue:
                transactionLockRequests.append(item.hash)

            case DashInventoryType.msgTxLockVote.rawValue:
                transactionLockVotes.append(item.hash)

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
