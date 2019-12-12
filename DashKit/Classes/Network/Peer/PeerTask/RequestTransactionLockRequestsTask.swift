import BitcoinCore

class RequestTransactionLockRequestsTask: PeerTask {

    var hashes = [Data]()
    var transactions = [FullTransaction]()

    init(hashes: [Data], dateGenerator: @escaping () -> Date = Date.init) {
        self.hashes = hashes

        super.init(dateGenerator: dateGenerator)
    }

    override func start() {
        let items = hashes.map { hash in InventoryItem(type: DashInventoryType.msgTxLockRequest.rawValue, hash: hash) }
        requester?.send(message: GetDataMessage(inventoryItems: items))

        super.start()
    }

    override func handle(message: IMessage) -> Bool {
        if let lockMessage = message as? TransactionLockMessage {
            return handleTransactionLockRequest(transaction: lockMessage.transaction)
        }
        return false
    }

    private func handleTransactionLockRequest(transaction: FullTransaction) -> Bool {
        guard let index = hashes.firstIndex(of: transaction.header.dataHash) else {
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
