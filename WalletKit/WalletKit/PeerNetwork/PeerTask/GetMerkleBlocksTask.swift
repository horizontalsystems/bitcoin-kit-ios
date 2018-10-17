import Foundation

class GetMerkleBlocksTask: PeerTask {

    var givenBlockHashes: [Data]
    private var hashesToDownload: [Data]
    private var pendingMerkleBlocks = [MerkleBlock]()
    private var nextBlockNotFull = true

    init(hashes: [Data]) {
        self.givenBlockHashes = hashes
        self.hashesToDownload = hashes
    }

    override func start() {
        let items = hashesToDownload.map { hash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: hash)
        }

        requester?.getData(items: items)
    }

    override func handle(merkleBlock: MerkleBlock) -> Bool {
        guard hashesToDownload.contains(merkleBlock.headerHash) else {
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
        return hashesToDownload.contains(hash)
    }

    private func handle(completeMerkleBlock merkleBlock: MerkleBlock) {
        if let index = hashesToDownload.index(where: { $0 == merkleBlock.headerHash }) {
            hashesToDownload.remove(at: index)
        }

        do {
            try delegate?.handle(merkleBlock: merkleBlock, fullBlock: nextBlockNotFull)
        } catch {
            if type(of: error) == BlockSyncer.BlockSyncerError.self {
                nextBlockNotFull = false
            }
        }

        if hashesToDownload.isEmpty {
            delegate?.handle(completedTask: self)
        }
    }

}
