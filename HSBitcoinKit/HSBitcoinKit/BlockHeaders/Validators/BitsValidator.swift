import Foundation

class BitsValidator: IBlockValidator {

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard candidate.bits == block.bits else {
            throw BlockValidatorError.notEqualBits
        }
    }

}
