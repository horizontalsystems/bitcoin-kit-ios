import Foundation

class RequestTransactionsTask: PeerTask {

    private var hashes: [Data]
    var transactions = [Transaction]()

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        let items = hashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)
        }

        requester?.getData(items: items)
    }

    override func handle(transaction: Transaction) -> Bool {
        guard let index = hashes.index(where: { $0 == transaction.dataHash }) else {
            return false
        }

        hashes.remove(at: index)
        transactions.append(transaction)

        if hashes.isEmpty {
            delegate?.handle(completedTask: self)
        }

        return true
    }

    override func isRequestingInventory(hash: Data) -> Bool {
        return hashes.contains(hash)
    }

    func equalTo(_ task: RequestTransactionsTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return hashes == task.hashes
    }
}
