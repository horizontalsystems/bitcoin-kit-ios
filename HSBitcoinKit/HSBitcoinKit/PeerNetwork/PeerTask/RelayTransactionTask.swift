import Foundation

class RelayTransactionTask: PeerTask {

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

        delegate?.handle(completedTask: self)

        return true
    }

}

extension RelayTransactionTask: Equatable {

    static func ==(lhs: RelayTransactionTask, rhs: RelayTransactionTask) -> Bool {
        return lhs.transaction.reversedHashHex == rhs.transaction.reversedHashHex
    }

}