import Foundation

class RequestMerkleBlocksPeerTask: PeerTask {

    private var hashes: [Data]
    private var pendingMerkleBlocks = [MerkleBlock]()
    var merkleBlocks = [MerkleBlock]()

    init(hashes: [Data]) {
        self.hashes = hashes
    }

    override func start() {
        let items = hashes.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: hash)
        }

        requester?.requestData(items: items)
    }

    override func handle(merkleBlock: MerkleBlock) -> Bool {
        guard hashes.contains(merkleBlock.headerHash) else {
            return false
        }

        if merkleBlock.complete {
            handle(completeMerkleBlock: merkleBlock)
        } else {
            pendingMerkleBlocks.append(merkleBlock)
        }

        return true
    }

    override func handle(transaction: Transaction) -> Bool {
        if let index = pendingMerkleBlocks.index(where: { $0.transactionHashes.contains(transaction.dataHash) }) {
            let block = pendingMerkleBlocks[index]

            block.transactions.append(transaction)

            if block.complete {
                pendingMerkleBlocks.remove(at: index)
                handle(completeMerkleBlock: block)
            }

            return true
        }

        return false
    }

    override func isRequestingInventory(hash: Data) -> Bool {
        return hashes.contains(hash)
    }

    private func handle(completeMerkleBlock merkleBlock: MerkleBlock) {
        if let index = hashes.index(where: { $0 == merkleBlock.headerHash }) {
            hashes.remove(at: index)
        }

        merkleBlocks.append(merkleBlock)

        if hashes.isEmpty {
            completed = true
            delegate?.handle(task: self)
        }
    }

}
