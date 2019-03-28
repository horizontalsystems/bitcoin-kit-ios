import Foundation
import BigInt

class HeaderValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder

    init(encoder: IDifficultyEncoder) {
        difficultyEncoder = encoder
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard candidate.previousBlockHashReversedHex.reversedData == block.headerHash else {
            throw BlockValidatorError.wrongPreviousHeaderHash
        }
        guard let headerHashBigInt = BigInt(candidate.headerHashReversedHex, radix: 16),
              headerHashBigInt < difficultyEncoder.decodeCompact(bits: candidate.bits) else {
            throw BlockValidatorError.invalidProveOfWork
        }

    }

}
