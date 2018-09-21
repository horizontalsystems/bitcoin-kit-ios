import Foundation

class PeerTask {

    weak var requester: IPeerTaskRequester?
    weak var delegate: IPeerTaskDelegate?

    var completed: Bool = false

    func start() {
    }

    func handle(blockHeaders: [BlockHeader]) -> Bool {
        return false
    }

    func handle(merkleBlock: MerkleBlock) -> Bool {
        return false
    }

    func handle(transaction: Transaction) -> Bool {
        return false
    }

    func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        return false
    }

    func handle(inventoryItem item: InventoryItem) -> Bool {
        return false
    }

    func handleRelayedTransaction(hash: Data) -> Bool {
        return false
    }

    func isRequestingInventory(hash: Data) -> Bool {
        return false
    }

}

protocol IPeerTaskDelegate: class {
    func handle(task: PeerTask)
}

protocol IPeerTaskRequester: class {
    func requestHeaders(hashes: [Data])
    func requestData(items: [InventoryItem])
    func sendTransactionInventory(hash: Data)
    func send(transaction: Transaction)
}
