import Foundation
import BigInt

class TestNetBlockValidator: BlockValidator {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    override func validate(block: Block) throws {
        guard let previousBlock = block.previousBlock else {
            throw ValidatorError.noPreviousBlock
        }
        guard let blockHeader = block.header, let previousBlockHeader = previousBlock.header else {
            throw Block.BlockError.noHeader
        }

        if !isDifficultyTransitionPoint(height: block.height), previousBlockHeader.timestamp > TestNetBlockValidator.testNetDiffDate {
            try validateHash(block: block)

            let timeDelta = blockHeader.timestamp - previousBlockHeader.timestamp
            if timeDelta >= 0, timeDelta <= calculator.targetSpacing * 2 {
                var cursorBlock = previousBlock
                guard let header = cursorBlock.header else {
                    throw Block.BlockError.noHeader
                }
                var cursorBlockHeader = header

                let maxDifficulty = calculator.maxTargetDifficulty

                while cursorBlock.height != 0 && !isDifficultyTransitionPoint(height: cursorBlock.height) && calculator.difficultyEncoder.decodeCompact(bits: cursorBlockHeader.bits) == maxDifficulty {
                    guard let previousBlock = cursorBlock.previousBlock, let header = previousBlock.header else {
                        throw ValidatorError.noPreviousBlock
                    }
                    cursorBlock = previousBlock
                    cursorBlockHeader = header
                }
                let cursorDifficulty = calculator.difficultyEncoder.decodeCompact(bits: cursorBlockHeader.bits)
                let itemDifficulty = calculator.difficultyEncoder.decodeCompact(bits: blockHeader.bits)

                if cursorDifficulty != itemDifficulty {
                    throw ValidatorError.notEqualBits
                }
            }
        } else {
            try super.validate(block: block)
        }
    }

}
