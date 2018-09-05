import Foundation

class ValidatedBlockFactory {

    private let realmFactory: RealmFactory
    private let factory: Factory
    private let validator: BlockValidator
    private let network: NetworkProtocol

    init(realmFactory: RealmFactory, factory: Factory, validator: BlockValidator, network: NetworkProtocol) {
        self.realmFactory = realmFactory
        self.factory = factory
        self.validator = validator
        self.network = network
    }

    func block(fromHeader header: BlockHeader, previousBlock: Block? = nil) throws -> Block {
        let resolvedPreviousBlock: Block

        if let previousBlock = previousBlock {
            resolvedPreviousBlock = previousBlock
        } else {
            let realm = realmFactory.realm
            let blockInChain = realm.objects(Block.self).filter("previousBlock != nil").sorted(byKeyPath: "height")
            resolvedPreviousBlock = blockInChain.last ?? network.checkpointBlock
        }

        let block = factory.block(withHeader: header, previousBlock: resolvedPreviousBlock)
        try validator.validate(block: block)
        return block
    }

}
