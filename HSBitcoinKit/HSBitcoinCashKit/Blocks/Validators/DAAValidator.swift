import BigInt

class DAAValidator: IBlockValidator {
    private let largestHash = BigInt(1) << 256
    private let consensusDaaForkHeight = 504030                             // 2017 November 13, 14:06 GMT

    private let difficultyEncoder: IDifficultyEncoder
    private let blockHelper: IBitcoinCashBlockValidatorHelper
    private let targetSpacing: Int
    private let heightInterval: Int
    private let firstCheckpointHeight: Int

    init(encoder: IDifficultyEncoder, blockHelper: IBitcoinCashBlockValidatorHelper, targetSpacing: Int, heightInterval: Int, firstCheckpointHeight: Int) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper

        self.targetSpacing = targetSpacing
        self.heightInterval = heightInterval
        self.firstCheckpointHeight = firstCheckpointHeight
    }

    func validate(block: Block, previousBlock: Block) throws {
        guard previousBlock.height >= firstCheckpointHeight + self.heightInterval + 3 else {
            return                                                                              // we must trust first 147 blocks from checkpoint, because can't calculate it's bits
        }

        let lastBlock = try blockHelper.suitableBlock(for: previousBlock)
        guard let previousWindowBlock = blockHelper.previous(for: previousBlock, count: self.heightInterval) else {
             throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
        }
        let firstBlock = try blockHelper.suitableBlock(for: previousWindowBlock)
        let heightInterval = lastBlock.height - firstBlock.height

        guard var blocks = blockHelper.previousWindow(for: lastBlock, count: heightInterval - 1) else {
            throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
        }
        blocks.append(lastBlock)

        var timeSpan = lastBlock.timestamp - lastBlock.timestamp
        if timeSpan > 2 * heightInterval * targetSpacing {
            timeSpan = 2 * heightInterval * targetSpacing
        } else if timeSpan < heightInterval / 2 * targetSpacing {
            timeSpan = heightInterval / 2 * targetSpacing
        }

        var chainWork = BigInt(0)
        for i in 0..<blocks.count {
            let target = difficultyEncoder.decodeCompact(bits: blocks[i].bits)
            chainWork += largestHash / (target + 1)
        }
        let projectedWork = chainWork * BigInt(targetSpacing) / BigInt(timeSpan)

        let target = largestHash / projectedWork - BigInt(1)

        let bits = difficultyEncoder.encodeCompact(from: target)

        guard bits == block.bits else {
            throw BlockValidatorError.notEqualBits
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        return previousBlock.height >= consensusDaaForkHeight // https://news.bitcoin.com/bitcoin-cash-network-completes-a-successful-hard-fork/
    }

}
