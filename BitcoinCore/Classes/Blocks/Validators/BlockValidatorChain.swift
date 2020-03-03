public class BlockValidatorChain: IBlockValidator {
    private var validators = [IBlockChainedValidator]()

    public init() {
    }

    public func validate(block: Block, previousBlock: Block) throws {
        if let index = validators.firstIndex(where: { $0.isBlockValidatable(block: block, previousBlock: previousBlock) }) {
            try validators[index].validate(block: block, previousBlock: previousBlock)
        }
    }

    public func add(blockValidator: IBlockChainedValidator) {
        validators.append(blockValidator)
    }

}
