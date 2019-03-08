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

        guard block.height >= 24 else {
            if candidateHeader.bits != network.maxTargetBits {
                throw BlockValidatorError.notEqualBits
            }
            return
        }

        let blockTarget = difficultyEncoder.decodeCompact(bits: blockHeader.bits)

        if network is DashTestNet {
            if candidateHeader.timestamp > blockHeader.timestamp + 7200 { // more than 2 hours
                if candidateHeader.bits != network.maxTargetBits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
            if candidateHeader.timestamp > blockHeader.timestamp + Int(network.targetSpacing * 4) {
                var newTarget = blockTarget * 10
                let compact = min(network.maxTargetBits, difficultyEncoder.encodeCompact(from: newTarget))
                if compact != candidateHeader.bits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
        }

        var avgTargets = blockTarget
        var prevBlock: Block? = block.previousBlock

        for it in 2..<25 {
            guard let currentBlock = prevBlock else {
                throw BlockValidatorError.noPreviousBlock
            }
            guard let header = currentBlock.header else {
                throw Block.BlockError.noHeader
            }
            let currentTarget = difficultyEncoder.decodeCompact(bits: header.bits)
            avgTargets = (avgTargets * BigInt(it) + currentTarget) / BigInt(it + 1)

            if it < 24 {
                prevBlock = currentBlock.previousBlock
            }
        }
        let firstTimestamp = prevBlock?.header?.timestamp ?? 0
        let lastTimestamp = blockHeader.timestamp
        var actualTimeSpan = lastTimestamp - firstTimestamp

        var darkTarget = avgTargets
        var targetTimeSpan = 24 * network.targetSpacing
        if (actualTimeSpan < targetTimeSpan / 3) {
            actualTimeSpan = targetTimeSpan / 3
        } else if (actualTimeSpan > targetTimeSpan * 3) {
            actualTimeSpan = targetTimeSpan * 3
        }

        darkTarget = darkTarget * BigInt(actualTimeSpan) / BigInt(targetTimeSpan)
        let compact = min(network.maxTargetBits, difficultyEncoder.encodeCompact(from: darkTarget))

        if compact != candidateHeader.bits {
            throw BlockValidatorError.notEqualBits
        }
    }

}

