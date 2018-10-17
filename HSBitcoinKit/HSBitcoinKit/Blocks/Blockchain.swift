import RealmSwift
import Foundation

class Blockchain {
    private let network: NetworkProtocol
    private let factory: Factory

    init(network: NetworkProtocol, factory: Factory) {
        self.network = network
        self.factory = factory
    }

    func connect(merkleBlock: MerkleBlock, realm: Realm) throws -> Block? {
        if let _ = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.headerHash).first {
            return nil
        }

        guard let previousBlock = realm.objects(Block.self).filter("headerHash = %@", merkleBlock.header.previousBlockHeaderHash).first else {
            throw BlockValidatorError.noPreviousBlock
        }

        // Validate and chain new blocks
        let block = factory.block(withHeader: merkleBlock.header, previousBlock: previousBlock)
        try network.validate(block: block, previousBlock: previousBlock)

        return block
    }
}
