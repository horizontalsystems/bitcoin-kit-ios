import RealmSwift

class Blockchain {
    private let network: INetwork
    private let factory: IFactory

    init(network: INetwork, factory: IFactory) {
        self.network = network
        self.factory = factory
    }

}

extension Blockchain: IBlockchain {

    func connect(merkleBlock: MerkleBlock, realm: Realm) throws -> Block {
        if let existingBlock = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.headerHash).first {
            return existingBlock
        }

        guard let previousBlock = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.header.previousBlockHeaderHash).first else {
            throw BlockValidatorError.noPreviousBlock
        }

        // Validate and chain new blocks
        let block = factory.block(withHeader: merkleBlock.header, previousBlock: previousBlock)
        try network.validate(block: block, previousBlock: previousBlock)
        block.stale = true
        realm.add(block)

        return block
    }

    func forceAdd(merkleBlock: MerkleBlock, height: Int, realm: Realm) -> Block {
        let block = factory.block(withHeader: merkleBlock.header, height: height)
        realm.add(block)

        return block
    }

    func handleFork(realm: Realm) {
        guard let firstStaleHeight = realm.objects(Block.self).filter("stale = %@", true).sorted(byKeyPath: "height").first?.height else {
            return
        }

        let lastNotStaleHeight = realm.objects(Block.self).filter("stale = %@", false).sorted(byKeyPath: "height").last?.height ?? 0

        try? realm.write {
            if (firstStaleHeight <= lastNotStaleHeight) {
                let lastStaleHeight = realm.objects(Block.self).filter("stale = %@", true).sorted(byKeyPath: "height").last?.height ?? firstStaleHeight

                if (lastStaleHeight > lastNotStaleHeight) {
                    let notStaleBlocks = realm.objects(Block.self).filter("stale = %@ AND height >= %@", false, firstStaleHeight)
                    realm.delete(notStaleBlocks)
                } else {
                    let staleBlocks = realm.objects(Block.self).filter("stale = %@", true)
                    realm.delete(staleBlocks)
                }
            }

            for block in realm.objects(Block.self).filter("stale = %@", true) {
                block.stale = false
            }
        }

    }

}
