import Foundation

class SendTransactionTask: PeerTask {

    var transaction: FullTransaction

    init(transaction: FullTransaction) {
        self.transaction = transaction
    }

    override func start() {
        requester?.sendTransactionInventory(hash: transaction.header.dataHash)
    }

    override func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        guard item.objectType == .transaction && item.hash == transaction.header.dataHash else {
            return false
        }

        requester?.send(transaction: transaction)
        delegate?.handle(completedTask: self)

        return true
    }

    func equalTo(_ task: SendTransactionTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return transaction.header.dataHash == task.transaction.header.dataHash
    }

}
