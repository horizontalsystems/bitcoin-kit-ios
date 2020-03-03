import Foundation
import BigInt

public class ProofOfWorkValidator: IBlockValidator {
    private let difficultyEncoder: IDifficultyEncoder

    public init(difficultyEncoder: IDifficultyEncoder) {
        self.difficultyEncoder = difficultyEncoder
    }

    public func validate(block: Block, previousBlock: Block) throws {
        guard let headerHashBigInt = BigInt(block.headerHash.reversedHex, radix: 16),
              headerHashBigInt < difficultyEncoder.decodeCompact(bits: block.bits) else {
            throw BitcoinCoreErrors.BlockValidation.invalidProofOfWork
        }
    }

}
