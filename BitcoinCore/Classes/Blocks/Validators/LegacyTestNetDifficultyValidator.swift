import Foundation
import BigInt

public class LegacyTestNetDifficultyValidator: IBlockChainedValidator {
    private let diffDate = 1329264000 // February 16th 2012

    private let heightInterval: Int
    private let targetSpacing: Int
    private let maxTargetBits: Int

    private let blockHelper: IBlockValidatorHelper

    public init(blockHelper: IBlockValidatorHelper, heightInterval: Int, targetSpacing: Int, maxTargetBits: Int) {
        self.blockHelper = blockHelper

        self.heightInterval = heightInterval
        self.targetSpacing = targetSpacing
        self.maxTargetBits = maxTargetBits
    }

    public func validate(block: Block, previousBlock: Block) throws {
        let timeDelta = block.timestamp - previousBlock.timestamp
        if timeDelta >= 0, timeDelta <= targetSpacing * 2 {
            var cursorBlock = previousBlock

            while !(cursorBlock.height % heightInterval == 0) && cursorBlock.bits == maxTargetBits {
                guard let previousBlock = blockHelper.previous(for: cursorBlock, count: 1) else {
                    throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
                }
                cursorBlock = previousBlock
            }
            if cursorBlock.bits != block.bits {
                throw BitcoinCoreErrors.BlockValidation.notEqualBits
            }
        }
    }

    public func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return previousBlock.timestamp > diffDate
    }

}
