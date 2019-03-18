class RequestTransactionLockRequestsTask: PeerTask {

    var hashes = [Data]()
    var transactions = [Transaction]()

    init(hashes: [Data], dateGenerator: @escaping () -> Date = Date.init) {
        self.hashes = hashes

        super.init(dateGenerator: dateGenerator)
    }

    override func start() {
        requester?.getData(items: hashes.map { hash in InventoryItem(type: InventoryType.msgTxLockRequest.rawValue, hash: hash) })
        resetTimer()
    }

    override func handle(message: IMessage) -> Bool {
        if let lockMessage = message as? TransactionLockMessage {
            return handleTransactionLockRequest(transaction: lockMessage.transaction)
        }
        return false
    }

    private func handleTransactionLockRequest(transaction: Transaction) -> Bool {
        guard let index = hashes.firstIndex(of: transaction.dataHash) else {
            return false
        }

        hashes.remove(at: index)
        transactions.append(transaction)
        if hashes.isEmpty {
            delegate?.handle(completedTask: self)
        }

        return true
    }

}
