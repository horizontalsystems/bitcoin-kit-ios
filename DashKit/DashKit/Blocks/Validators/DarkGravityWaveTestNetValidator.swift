import BitcoinCore

class DarkGravityWaveTestNetValidator: IBlockValidator {
    private let difficultyEncoder: IDifficultyEncoder

    private let targetSpacing: Int
    private let targetTimeSpan: Int
    private let maxTargetBits: Int

    init(difficultyEncoder: IDifficultyEncoder, targetSpacing: Int, targetTimeSpan: Int, maxTargetBits: Int) {
        self.difficultyEncoder = difficultyEncoder

        self.targetSpacing = targetSpacing
        self.targetTimeSpan = targetTimeSpan
        self.maxTargetBits = maxTargetBits
    }

    func validate(block: Block, previousBlock: Block) throws {
        if block.timestamp > previousBlock.timestamp + 2 * targetTimeSpan { // more than 2 cycles
            if block.bits != maxTargetBits {
                throw BitcoinCoreErrors.BlockValidation.notEqualBits
            }
            return
        }

        let blockTarget = difficultyEncoder.decodeCompact(bits: previousBlock.bits)

        var expectedBits = difficultyEncoder.encodeCompact(from: 10 * blockTarget)
        if expectedBits > maxTargetBits {
            expectedBits = maxTargetBits
        }
        if expectedBits != block.bits {
            throw BitcoinCoreErrors.BlockValidation.notEqualBits
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return block.timestamp > previousBlock.timestamp + 4 * targetSpacing
    }

}
