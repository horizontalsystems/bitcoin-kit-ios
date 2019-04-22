import BitcoinCore
import BigInt

class EDAValidator: IBlockValidator {
    private let difficultyEncoder: IBitcoinCashDifficultyEncoder
    private let blockHelper: IBitcoinCashBlockValidatorHelper
    private let maxTargetBits: Int

    init(encoder: IBitcoinCashDifficultyEncoder, blockHelper: IBitcoinCashBlockValidatorHelper, maxTargetBits: Int) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper

        self.maxTargetBits = maxTargetBits
    }

    func validate(block: Block, previousBlock: Block) throws {
        if previousBlock.bits == maxTargetBits {
            if block.bits != maxTargetBits {
                throw BitcoinCoreErrors.BlockValidation.notEqualBits
            }
            return
        }
        guard let cursorBlock = blockHelper.previous(for: previousBlock, count: 6) else {
            throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
        }
        let mpt6blocks = blockHelper.medianTimePast(block: previousBlock) - blockHelper.medianTimePast(block: cursorBlock)
        if(mpt6blocks >= 12 * 3600) {
            let pow = difficultyEncoder.decodeCompact(bits: previousBlock.bits) >> 2
            let powBits = min(difficultyEncoder.encodeCompact(from: pow), maxTargetBits)

            guard powBits == block.bits else {
                throw BitcoinCoreErrors.BlockValidation.notEqualBits
            }
        } else {
            guard previousBlock.bits == block.bits else {
                throw BitcoinCoreErrors.BlockValidation.notEqualBits
            }
        }

    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return true
    }

}
