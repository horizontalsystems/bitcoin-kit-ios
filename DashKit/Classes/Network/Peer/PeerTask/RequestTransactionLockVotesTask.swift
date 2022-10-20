import BitcoinCore

class RequestTransactionLockVotesTask: PeerTask {

    var hashes = [Data]()
    var transactionLockVotes = [TransactionLockVoteMessage]()

    init(hashes: [Data], dateGenerator: @escaping () -> Date = Date.init) {
        self.hashes = hashes

        super.init(dateGenerator: dateGenerator)
    }

    override func start() {
        let items = hashes.map { hash in InventoryItem(type: DashInventoryType.msgTxLockVote.rawValue, hash: hash) }
        requester?.send(message: GetDataMessage(inventoryItems: items))

        super.start()
    }

    override func handle(message: IMessage) -> Bool {
        if let lockMessage = message as? TransactionLockVoteMessage {
            return handleTransactionLockRequest(transactionLockVote: lockMessage)
        }
        return false
    }

    private func handleTransactionLockRequest(transactionLockVote: TransactionLockVoteMessage) -> Bool {
        guard let index = hashes.firstIndex(of: transactionLockVote.hash) else {
            return false
        }

        hashes.remove(at: index)
        transactionLockVotes.append(transactionLockVote)
        if hashes.isEmpty {
            delegate?.handle(completedTask: self)
        }

        return true
    }

}
