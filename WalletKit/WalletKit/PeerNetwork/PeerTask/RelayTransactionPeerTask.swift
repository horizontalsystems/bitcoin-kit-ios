import Foundation

class RelayTransactionPeerTask: PeerTask {

    var transaction: Transaction

    init(transaction: Transaction) {
        self.transaction = transaction
    }

    override func start() {
        requester?.sendTransactionInventory(hash: transaction.dataHash)
    }

    override func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        guard item.objectType == .transaction && item.hash == transaction.dataHash else {
            return false
        }

        requester?.send(transaction: transaction)

        return true
    }

    override func handleRelayedTransaction(hash: Data) -> Bool {
        guard hash == transaction.dataHash else {
            return false
        }

        completed = true
        delegate?.handle(task: self)

        return true
    }

}
