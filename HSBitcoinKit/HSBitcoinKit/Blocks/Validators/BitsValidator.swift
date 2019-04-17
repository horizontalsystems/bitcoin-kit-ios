import Foundation

class BitsValidator: IBlockValidator {

    func validate(block: Block, previousBlock: Block) throws {
        guard block.bits == previousBlock.bits else {
            throw BitcoinCoreErrors.BlockValidation.notEqualBits
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

}
