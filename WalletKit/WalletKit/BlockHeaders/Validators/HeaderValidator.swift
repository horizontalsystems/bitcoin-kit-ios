import Foundation

class HeaderValidator: IBlockValidator {

    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws {
        guard let candidateHeader = candidate.header else {
            throw Block.BlockError.noHeader
        }
        guard candidateHeader.previousBlockHeaderHash == block.headerHash else {
            throw BlockValidatorError.wrongPreviousHeaderHash
        }
    }

}
