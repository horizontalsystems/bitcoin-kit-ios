import Foundation

class RelayTransactionPeerTask: PeerTask {

    private var transaction: Transaction

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
        delegate?.completed(task: self)

        return true
    }

//    override func handle(inventoryItem item: InventoryItem) -> Bool {
//        guard item.objectType == .transaction && item.hash == transaction.dataHash else {
//            return false
//        }
//
//        delegate?.completed(task: self)
//
//        return true
//    }

}
