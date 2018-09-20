import Foundation

class RequestTransactionsPeerTask: PeerTask {

    private var hashes: [Data]

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        let items = hashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)
        }

        requester?.requestData(items: items)
    }

    override func handle(transaction: Transaction) -> Bool {
        guard let index = hashes.index(where: { $0 == transaction.dataHash }) else {
            return false
        }

        hashes.remove(at: index)

        delegate?.received(transaction: transaction)

        if hashes.isEmpty {
            delegate?.completed(task: self)
        }

        return true
    }

    override func isRequestingInventory(hash: Data) -> Bool {
        return hashes.contains(hash)
    }

}
