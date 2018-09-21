import Foundation
import BigInt

class EDAValidator: IBlockValidator {
    let difficultyEncoder: DifficultyEncoder
    let blockHelper: BlockHelper

    init(encoder: DifficultyEncoder, blockHelper: BlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws {
        guard let candidateHeader = candidate.header, let blockHeader = block.header else {
            throw Block.BlockError.noHeader
        }
        if blockHeader.bits == network.maxTargetBits {
            if candidateHeader.bits != network.maxTargetBits {
                throw BlockValidatorError.notEqualBits
            }
            return
        }
        guard let cursorBlock = blockHelper.previous(for: block, index: 6) else {
            throw BlockValidatorError.noPreviousBlock
        }
        let mpt6blocks = try blockHelper.medianTimePast(block: block) - blockHelper.medianTimePast(block: cursorBlock)
        if(mpt6blocks >= 12 * 3600) {
            var pow = difficultyEncoder.decodeCompact(bits: blockHeader.bits) >> 2
            pow = min(pow, difficultyEncoder.decodeCompact(bits: network.maxTargetBits))

            guard difficultyEncoder.encodeCompact(from: pow) == candidateHeader.bits else {
                throw BlockValidatorError.notEqualBits
            }
        } else {
            guard blockHeader.bits == candidateHeader.bits else {
                throw BlockValidatorError.notEqualBits
            }
        }
    }

}
