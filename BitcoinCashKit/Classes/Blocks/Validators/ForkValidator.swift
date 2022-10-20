import BitcoinCore

class ForkValidator: IBlockChainedValidator {
    private let concreteValidator: IBitcoinCashBlockValidator
    private let forkHeight: Int
    private let expectedBlockHash: Data

    init(concreteValidator: IBitcoinCashBlockValidator, forkHeight: Int, expectedBlockHash: Data) {
        self.concreteValidator = concreteValidator
        self.forkHeight = forkHeight
        self.expectedBlockHash = expectedBlockHash
    }

    func validate(block: Block, previousBlock: Block) throws {
        if block.headerHash != expectedBlockHash {
            throw BitcoinCoreErrors.BlockValidation.wrongHeaderHash
        }

        try concreteValidator.validate(block: block, previousBlock: previousBlock)
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        block.height == forkHeight
    }

}
