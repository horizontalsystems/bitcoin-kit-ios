import Foundation

class BitsValidator: IBlockValidator {

    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws {
        guard let candidateHeader = candidate.header, let blockHeader = block.header else {
            throw Block.BlockError.noHeader
        }
        guard candidateHeader.bits == blockHeader.bits else {
            throw BlockValidatorError.notEqualBits
        }
    }

}
