import Foundation

class RequestTransactionsTask: PeerTask {

    private var hashes: [Data]
    var transactions = [FullTransaction]()

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        let items = hashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: hash)
        }

        requester?.getData(items: items)
    }

    override func handle(transaction: FullTransaction) -> Bool {
        guard let index = hashes.index(where: { $0 == transaction.header.dataHash }) else {
            return false
        }

        hashes.remove(at: index)
        transactions.append(transaction)

        if hashes.isEmpty {
            delegate?.handle(completedTask: self)
        }

        return true
    }

    func equalTo(_ task: RequestTransactionsTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return hashes == task.hashes
    }
}
