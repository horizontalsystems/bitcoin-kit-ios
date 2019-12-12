import BitcoinCore

class ForkValidator: IBlockValidator {
    private let concreteValidator: IBitcoinCashBlockValidator
    private let forkHeight: Int
    private let expectedBlockHash: Data

    init(concreteValidator: IBitcoinCashBlockValidator, forkHeight: Int, expectedBlockHash: Data) {
        self.concreteValidator = concreteValidator
        self.forkHeight = forkHeight
        self.expectedBlockHash = expectedBlockHash
    }

    func validate(block: Block, previousBlock: Block) throws {
        if block.height == forkHeight, block.headerHash != expectedBlockHash {
            throw BitcoinCoreErrors.BlockValidation.wrongHeaderHash
        }

        try concreteValidator.validate(block: block, previousBlock: previousBlock)
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

}
