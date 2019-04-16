import Foundation
import BigInt

class HeaderValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder

    init(encoder: IDifficultyEncoder) {
        difficultyEncoder = encoder
    }

    func validate(block: Block, previousBlock: Block) throws {
        guard let headerHashBigInt = BigInt(block.headerHashReversedHex, radix: 16),
              headerHashBigInt < difficultyEncoder.decodeCompact(bits: block.bits) else {
            throw BitcoinCoreErrors.BlockValidation.invalidProofOfWork
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

}
