import Foundation

class SendTransactionTask: PeerTask {

    var transaction: Transaction

    init(transaction: Transaction) {
        // Transaction is managed by Realm. We need to serialize and deserialize it in order to make it non-managed.
        let data = TransactionSerializer.serialize(transaction: transaction)
        let transaction = TransactionSerializer.deserialize(data: data)

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
        delegate?.handle(completedTask: self)

        return true
    }

    func equalTo(_ task: SendTransactionTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return transaction.reversedHashHex == task.transaction.reversedHashHex
    }

}
