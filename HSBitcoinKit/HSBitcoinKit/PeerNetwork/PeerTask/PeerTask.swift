import Foundation

class PeerTask {

    weak var requester: IPeerTaskRequester?
    weak var delegate: IPeerTaskDelegate?

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

    func handle(items: [InventoryItem]) -> Bool {
        return false
    }

    func handleRelayedTransaction(hash: Data) -> Bool {
        return false
    }

    func isRequestingInventory(hash: Data) -> Bool {
        return false
    }

    func handle(pongNonce: UInt64) -> Bool {
        return false
    }
}

protocol IPeerTaskDelegate: class {
    func handle(completedTask task: PeerTask)
    func handle(failedTask task: PeerTask, error: Error)
    func handle(merkleBlock: MerkleBlock)
}
