import Foundation
import BigInt

class DarkGravityWaveValidator: IBlockValidator {
    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(encoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard let candidateHeader = candidate.header, let blockHeader = block.header else {
            throw Block.BlockError.noHeader
        }
        guard block.height >= network.heightInterval else {
            if candidateHeader.bits != network.maxTargetBits {
                throw BlockValidatorError.notEqualBits
            }
            return
        }

        let blockTarget = difficultyEncoder.decodeCompact(bits: blockHeader.bits)

        if network is DashTestNet {
            if candidateHeader.timestamp > blockHeader.timestamp + 2 * network.targetTimeSpan { // more than 2 hours
                if candidateHeader.bits != network.maxTargetBits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
            if candidateHeader.timestamp > blockHeader.timestamp + 4 * network.targetSpacing {
                let newTarget = 10 * blockTarget
                let compact = min(network.maxTargetBits, difficultyEncoder.encodeCompact(from: newTarget))
                if compact != candidateHeader.bits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
        }

        var actualTimeSpan = 0
        var avgTargets = blockTarget
        var prevBlock: Block? = block.previousBlock

        for blockCount in 2..<(network.heightInterval + 1) {
            guard let currentBlock = prevBlock else {
                throw BlockValidatorError.noPreviousBlock
            }
            guard let header = currentBlock.header else {
                throw Block.BlockError.noHeader
            }
            let currentTarget = difficultyEncoder.decodeCompact(bits: header.bits)
            avgTargets = (avgTargets * BigInt(blockCount) + currentTarget) / BigInt(blockCount + 1)

            if blockCount < network.heightInterval {
                prevBlock = currentBlock.previousBlock
            } else {
                actualTimeSpan = blockHeader.timestamp - header.timestamp
            }
        }
        var darkTarget = avgTargets
        if (actualTimeSpan < network.targetTimeSpan / 3) {
            actualTimeSpan = network.targetTimeSpan / 3
        } else if (actualTimeSpan > network.targetTimeSpan * 3) {
            actualTimeSpan = network.targetTimeSpan * 3
        }

        darkTarget = darkTarget * BigInt(actualTimeSpan) / BigInt(network.targetTimeSpan)
        let compact = min(network.maxTargetBits, difficultyEncoder.encodeCompact(from: darkTarget))

        if compact != candidateHeader.bits {
            throw BlockValidatorError.notEqualBits
        }
    }

}
