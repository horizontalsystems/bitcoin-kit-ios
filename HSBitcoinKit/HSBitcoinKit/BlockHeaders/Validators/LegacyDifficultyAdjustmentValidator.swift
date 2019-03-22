import BigInt

class LegacyDifficultyAdjustmentValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(encoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    private func limit(timeSpan: Int, targetTimeSpan: Int) -> Int {
        return min(max(timeSpan, targetTimeSpan / 4), targetTimeSpan * 4)
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard let firstBlock = blockHelper.previous(for: block, index: network.heightInterval - 1) else {
            throw BlockValidatorError.noPreviousBlock
        }
        let timeSpan = limit(timeSpan: block.timestamp - firstBlock.timestamp, targetTimeSpan: network.targetTimeSpan)

        var bigIntDifficulty = difficultyEncoder.decodeCompact(bits: block.bits)
        bigIntDifficulty *= BigInt(timeSpan)
        bigIntDifficulty /= BigInt(network.targetTimeSpan)
        let newDifficulty = min(difficultyEncoder.encodeCompact(from: bigIntDifficulty), network.maxTargetBits)

        guard newDifficulty == candidate.bits else {
            throw BlockValidatorError.notDifficultyTransitionEqualBits
        }
    }

}
