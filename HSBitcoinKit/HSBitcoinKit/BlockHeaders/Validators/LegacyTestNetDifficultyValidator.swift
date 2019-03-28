import Foundation
import BigInt

class LegacyTestNetDifficultyValidator: IBlockValidator {
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        let timeDelta = candidate.timestamp - block.timestamp
        if timeDelta >= 0, timeDelta <= network.targetSpacing * 2 {
            var cursorBlock = block

            while cursorBlock.height != 0 && !(cursorBlock.height % network.heightInterval == 0) && cursorBlock.bits == network.maxTargetBits {
                guard let previousBlock = cursorBlock.previousBlock(storage: storage) else {
                    throw BlockValidatorError.noPreviousBlock
                }
                cursorBlock = previousBlock
            }
            if cursorBlock.bits != candidate.bits {
                throw BlockValidatorError.notEqualBits
            }
        }
    }

}
