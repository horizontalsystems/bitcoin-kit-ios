import Foundation
import BigInt

class HeaderValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder

    init(encoder: IDifficultyEncoder) {
        difficultyEncoder = encoder
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard let candidateHeader = candidate.header else {
            throw Block.BlockError.noHeader
        }
        guard candidateHeader.previousBlockHeaderHash == block.headerHash else {
            throw BlockValidatorError.wrongPreviousHeaderHash
        }
        guard let headerHashBigInt = BigInt(candidate.reversedHeaderHashHex, radix: 16),
              headerHashBigInt < difficultyEncoder.decodeCompact(bits: candidateHeader.bits) else {
            throw BlockValidatorError.invalidProofOfWork
        }

    }

}
