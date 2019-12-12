class BlockValidatorChain: IBlockValidator {
    private let proofOfWorkValidator: IBlockValidator
    private var concreteValidators = [IBlockValidator]()

    init(proofOfWorkValidator: IBlockValidator) {
        self.proofOfWorkValidator = proofOfWorkValidator
    }

    func validate(block: Block, previousBlock: Block) throws {
        try proofOfWorkValidator.validate(block: block, previousBlock: previousBlock)

        if let index = concreteValidators.firstIndex(where: { $0.isBlockValidatable(block: block, previousBlock: previousBlock) }) {
            try concreteValidators[index].validate(block: block, previousBlock: previousBlock)
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

    func add(blockValidator: IBlockValidator) {
        concreteValidators.append(blockValidator)
    }

}
