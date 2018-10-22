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

    func connect(merkleBlock: MerkleBlock, realm: Realm) throws -> Block? {
        if let existingBlock = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.headerHash).first {
            return existingBlock
        }

        guard let previousBlock = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.header.previousBlockHeaderHash).first else {
            throw BlockValidatorError.noPreviousBlock
        }

        // Validate and chain new blocks
        let block = factory.block(withHeader: merkleBlock.header, previousBlock: previousBlock)
        try network.validate(block: block, previousBlock: previousBlock)
        realm.add(block)

        return block
    }

}
