public class BlockValidatorSet: IBlockValidator {
    private var validators = [IBlockValidator]()

    public init() {
    }

    public func validate(block: Block, previousBlock: Block) throws {
        for validator in validators {
            try validator.validate(block: block, previousBlock: previousBlock)
        }
    }

    public func add(blockValidator: IBlockValidator) {
        validators.append(blockValidator)
    }

}
