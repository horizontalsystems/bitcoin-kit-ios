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
        guard let candidateHeader = candidate.header, let blockHeader = block.header else {
            throw Block.BlockError.noHeader
        }
        guard let firstBlock = blockHelper.previous(for: block, index: network.heightInterval - 1) else {
            throw BlockValidatorError.noPreviousBlock
        }
        guard let firstBlockTime = firstBlock.header?.timestamp else {
            throw Block.BlockError.noHeader
        }
        let timeSpan = limit(timeSpan: blockHeader.timestamp - firstBlockTime, targetTimeSpan: network.targetTimeSpan)

        var bigIntDifficulty = difficultyEncoder.decodeCompact(bits: blockHeader.bits)
        bigIntDifficulty *= BigInt(timeSpan)
        bigIntDifficulty /= BigInt(network.targetTimeSpan)
        let newDifficulty = min(difficultyEncoder.encodeCompact(from: bigIntDifficulty), network.maxTargetBits)

        guard newDifficulty == candidateHeader.bits else {
            throw BlockValidatorError.notDifficultyTransitionEqualBits
        }
    }

}
