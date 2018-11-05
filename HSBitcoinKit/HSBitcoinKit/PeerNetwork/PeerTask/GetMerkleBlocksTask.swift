import Foundation

class GetMerkleBlocksTask: PeerTask {

    private var blockHashes: [BlockHash]
    private var pendingMerkleBlocks = [MerkleBlock]()

    init(blockHashes: [BlockHash]) {
        self.blockHashes = blockHashes
    }

    override func start() {
        let items = blockHashes.map { blockHash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: blockHash.headerHash)
        }

        requester?.getData(items: items)
    }

    override func handle(merkleBlock: MerkleBlock) -> Bool {
        guard let blockHash = blockHashes.first(where: { blockHash in blockHash.headerHash == merkleBlock.headerHash }) else {
            return false
        }

        merkleBlock.height = blockHash.height > 0 ? blockHash.height : nil

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

    private func handle(completeMerkleBlock merkleBlock: MerkleBlock) {
        if let index = blockHashes.index(where: { $0.headerHash == merkleBlock.headerHash }) {
            blockHashes.remove(at: index)
        }

        delegate?.handle(merkleBlock: merkleBlock)

        if blockHashes.isEmpty {
            delegate?.handle(completedTask: self)
        }
    }

}

extension GetMerkleBlocksTask: Equatable {

    static func ==(lhs: GetMerkleBlocksTask, rhs: GetMerkleBlocksTask) -> Bool {
        return lhs.blockHashes == rhs.blockHashes
    }

}
