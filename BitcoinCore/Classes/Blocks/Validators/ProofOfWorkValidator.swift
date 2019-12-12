import Foundation
import BigInt

class ProofOfWorkValidator: IBlockValidator {
    private let difficultyEncoder: IDifficultyEncoder

    init(difficultyEncoder: IDifficultyEncoder) {
        self.difficultyEncoder = difficultyEncoder
    }

    func validate(block: Block, previousBlock: Block) throws {

        guard let headerHashBigInt = BigInt(block.headerHash.reversedHex, radix: 16),
              headerHashBigInt < difficultyEncoder.decodeCompact(bits: block.bits) else {
            throw BitcoinCoreErrors.BlockValidation.invalidProofOfWork
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

}
