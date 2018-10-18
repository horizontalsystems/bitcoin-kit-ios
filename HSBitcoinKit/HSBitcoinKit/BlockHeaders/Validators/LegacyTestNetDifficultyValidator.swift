import Foundation
import BigInt

class LegacyTestNetDifficultyValidator: IBlockValidator {

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard let candidateHeader = candidate.header, let previousBlockHeader = block.header else {
            throw Block.BlockError.noHeader
        }

        let timeDelta = candidateHeader.timestamp - previousBlockHeader.timestamp
        if timeDelta >= 0, timeDelta <= network.targetSpacing * 2 {
            var cursorBlock = block
            guard let header = cursorBlock.header else {
                throw Block.BlockError.noHeader
            }
            var cursorBlockHeader = header

            while cursorBlock.height != 0 && !(cursorBlock.height % network.heightInterval == 0) && cursorBlockHeader.bits == network.maxTargetBits {
                guard let previousBlock = cursorBlock.previousBlock else {
                    throw BlockValidatorError.noPreviousBlock
                }
                guard let header = previousBlock.header else {
                    throw Block.BlockError.noHeader
                }
                cursorBlock = previousBlock
                cursorBlockHeader = header
            }
            if cursorBlockHeader.bits != candidateHeader.bits {
                throw BlockValidatorError.notEqualBits
            }
        }
    }

}
