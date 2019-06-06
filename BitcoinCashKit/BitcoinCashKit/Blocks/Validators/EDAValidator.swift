import BitcoinCore
import BigInt

class EDAValidator: IBlockValidator {
    private let difficultyEncoder: IBitcoinCashDifficultyEncoder
    private let blockHelper: IBitcoinCashBlockValidatorHelper
    private let maxTargetBits: Int
    private let firstCheckpointHeight: Int

    init(encoder: IBitcoinCashDifficultyEncoder, blockHelper: IBitcoinCashBlockValidatorHelper, maxTargetBits: Int, firstCheckpointHeight: Int) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper

        self.maxTargetBits = maxTargetBits
        self.firstCheckpointHeight = firstCheckpointHeight
    }

    func validate(block: Block, previousBlock: Block) throws {
        guard previousBlock.height >= firstCheckpointHeight + 6 else {
            return                                                                              // we must trust first 6 blocks from checkpoint, because can't calculate it's bits
        }

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
            let decodedBits = difficultyEncoder.decodeCompact(bits: previousBlock.bits)
            let pow = decodedBits >> 2
            let powBits = min(difficultyEncoder.encodeCompact(from: decodedBits + pow), maxTargetBits)

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
