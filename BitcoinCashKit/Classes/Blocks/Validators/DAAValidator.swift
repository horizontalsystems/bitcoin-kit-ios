import BitcoinCore
import BigInt

class DAAValidator: IBlockChainedValidator, IBitcoinCashBlockValidator {
    private let largestHash = BigInt(1) << 256
    private let consensusDaaForkHeight = 504031                             // 2017 November 13, 14:06 GMT

    private let difficultyEncoder: IDifficultyEncoder
    private let blockHelper: IBitcoinCashBlockValidatorHelper
    private let targetSpacing: Int
    private let heightInterval: Int

    init(encoder: IDifficultyEncoder, blockHelper: IBitcoinCashBlockValidatorHelper, targetSpacing: Int, heightInterval: Int) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper

        self.targetSpacing = targetSpacing
        self.heightInterval = heightInterval
    }

    func validate(block: Block, previousBlock: Block) throws {
        var blocks = blockHelper.previousWindow(for: previousBlock, count: 146) ?? [Block]()                                        // get all blocks without previousBlock needed for found suitable and range window

        guard !blocks.isEmpty else {
            throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
        }
        blocks.append(previousBlock)                                                                                                // add previous block to have all 147

        guard let newLastBlockShift = blockHelper.suitableBlockIndex(for: Array(blocks.suffix(from: blocks.count - 3))),            // get suitable index for last 3 blocks
              let newFirstBlockShift = blockHelper.suitableBlockIndex(for: Array(blocks.prefix(3))) else {                          // get suitable index for first 3 blocks

            throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
        }

        let startIndex = newFirstBlockShift + 1
        let finishIndex = blocks.count - 3 + newLastBlockShift

        var timeSpan = blocks[finishIndex].timestamp - blocks[newFirstBlockShift].timestamp
        if timeSpan > 2 * heightInterval * targetSpacing {
            timeSpan = 2 * heightInterval * targetSpacing
        } else if timeSpan < heightInterval / 2 * targetSpacing {
            timeSpan = heightInterval / 2 * targetSpacing
        }

        var chainWork = BigInt(0)
        for i in startIndex...finishIndex {
            let target = difficultyEncoder.decodeCompact(bits: blocks[i].bits)
            chainWork += largestHash / (target + 1)
        }
        let projectedWork = chainWork * BigInt(targetSpacing) / BigInt(timeSpan)

        let target = largestHash / projectedWork - BigInt(1)

        let bits = difficultyEncoder.encodeCompact(from: target)

        guard bits == block.bits else {
            throw BitcoinCoreErrors.BlockValidation.notEqualBits
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        previousBlock.height >= consensusDaaForkHeight // https://news.bitcoin.com/bitcoin-cash-network-completes-a-successful-hard-fork/
    }

}
