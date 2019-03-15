import RealmSwift

class Blockchain {
    private let storage: IStorage
    private let network: INetwork
    private let factory: IFactory
    weak var listener: IBlockchainDataListener?

    init(storage: IStorage, network: INetwork, factory: IFactory, listener: IBlockchainDataListener? = nil) {
        self.storage = storage
        self.network = network
        self.factory = factory
        self.listener = listener
    }

    private func unstaleAllBlocks(realm: Realm) {
        for block in storage.blocks(stale: true, realm: realm) {
            block.stale = false
            storage.update(block: block, realm: realm)
        }
    }

}

extension Blockchain: IBlockchain {

    func connect(merkleBlock: MerkleBlock, realm: Realm) throws -> Block {
        // realm.objects(Block.self).filter("headerHash = %@", merkleBlock.headerHash).first
        if let existingBlock = storage.block(byHashHex: merkleBlock.reversedHeaderHashHex) {
            return existingBlock
        }

        // realm.objects(Block.self).filter("headerHash = %@", merkleBlock.header.previousBlockHeaderHash).first
        guard let previousBlock = storage.block(byHashHex: merkleBlock.header.previousBlockHeaderHash.reversedHex) else {
            throw BlockValidatorError.noPreviousBlock
        }

        // Validate and chain new blocks
        let block = factory.block(withHeader: merkleBlock.header, previousBlock: previousBlock)
        try network.validate(block: block, previousBlock: previousBlock)
        block.stale = true

        storage.add(block: block, realm: realm)
        listener?.onInsert(block: block)

        return block
    }

    func forceAdd(merkleBlock: MerkleBlock, height: Int, realm: Realm) -> Block {
        let block = factory.block(withHeader: merkleBlock.header, height: height)
        storage.add(block: block, realm: realm)

        listener?.onInsert(block: block)

        return block
    }

    func handleFork() {
        guard let firstStaleHeight = storage.block(stale: true, sortedHeight: "ASC", realm: nil)?.height else {
            return
        }

        let lastNotStaleHeight = storage.block(stale: false, sortedHeight: "DESC", realm: nil)?.height ?? 0

        try? storage.inTransaction { realm in
            if (firstStaleHeight <= lastNotStaleHeight) {
                let lastStaleHeight = storage.block(stale: true, sortedHeight: "DESC", realm: realm)?.height ?? firstStaleHeight

                if (lastStaleHeight > lastNotStaleHeight) {
                    let notStaleBlocks = storage.blocks(heightGreaterThanOrEqualTo: firstStaleHeight, stale: false, realm: realm)
                    deleteBlocks(blocks: notStaleBlocks, realm: realm)
                    unstaleAllBlocks(realm: realm)
                } else {
                    let staleBlocks = storage.blocks(stale: true, realm: realm)
                    deleteBlocks(blocks: staleBlocks, realm: realm)
                }
            } else {
                unstaleAllBlocks(realm: realm)
            }
        }
    }

    func deleteBlocks(blocks: [Block], realm: Realm) {
        let hashes =  blocks.reduce(into: [String](), { acc, block in
            acc.append(contentsOf: storage.transactions(ofBlock: block, realm: realm).map { $0.reversedHashHex })
        })

        storage.delete(blocks: blocks, realm: realm)
        listener?.onDelete(transactionHashes: hashes)
    }

}
