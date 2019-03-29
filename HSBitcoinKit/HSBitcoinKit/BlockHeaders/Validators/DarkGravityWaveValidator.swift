import Foundation
import BigInt

class DarkGravityWaveValidator: IBlockValidator {
    private let difficultyEncoder: IDifficultyEncoder
    private let blockHelper: IBlockHelper
    private let storage: IStorage

    init(storage: IStorage, encoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        self.storage = storage
        self.difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        guard block.height >= network.heightInterval else {
            if candidate.bits != network.maxTargetBits {
                throw BlockValidatorError.notEqualBits
            }
            return
        }

        let blockTarget = difficultyEncoder.decodeCompact(bits: block.bits)

        if network is DashTestNet {
            if candidate.timestamp > block.timestamp + 2 * network.targetTimeSpan { // more than 2 hours
                if candidate.bits != network.maxTargetBits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
            if candidate.timestamp > block.timestamp + 4 * network.targetSpacing {
                let newTarget = 10 * blockTarget
                let compact = min(network.maxTargetBits, difficultyEncoder.encodeCompact(from: newTarget))
                if compact != candidate.bits {
                    throw BlockValidatorError.notEqualBits
                }
                return
            }
        }

        var actualTimeSpan = 0
        var avgTargets = blockTarget
        var prevBlock: Block? = block.previousBlock(storage: storage)

        for blockCount in 2..<(network.heightInterval + 1) {
            guard let currentBlock = prevBlock else {
                throw BlockValidatorError.noPreviousBlock
            }
            let currentTarget = difficultyEncoder.decodeCompact(bits: currentBlock.bits)
            avgTargets = (avgTargets * BigInt(blockCount) + currentTarget) / BigInt(blockCount + 1)

            if blockCount < network.heightInterval {
                prevBlock = currentBlock.previousBlock(storage: storage)
            } else {
                actualTimeSpan = block.timestamp - currentBlock.timestamp
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

        if compact != candidate.bits {
            throw BlockValidatorError.notEqualBits
        }
    }

}
