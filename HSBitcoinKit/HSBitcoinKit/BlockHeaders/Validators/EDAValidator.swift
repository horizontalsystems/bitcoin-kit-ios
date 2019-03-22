import BigInt

class EDAValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(encoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        if block.bits == network.maxTargetBits {
            if candidate.bits != network.maxTargetBits {
                throw BlockValidatorError.notEqualBits
            }
            return
        }
        guard let cursorBlock = blockHelper.previous(for: block, index: 6) else {
            throw BlockValidatorError.noPreviousBlock
        }
        let mpt6blocks = try blockHelper.medianTimePast(block: block) - blockHelper.medianTimePast(block: cursorBlock)
        if(mpt6blocks >= 12 * 3600) {
            let pow = difficultyEncoder.decodeCompact(bits: block.bits) >> 2
            let powBits = min(difficultyEncoder.encodeCompact(from: pow), network.maxTargetBits)

            guard powBits == candidate.bits else {
                throw BlockValidatorError.notEqualBits
            }
        } else {
            guard block.bits == candidate.bits else {
                throw BlockValidatorError.notEqualBits
            }
        }
    }

}
