import Foundation
import BigInt

class DAAValidator: IBlockValidator {
    private let largestHash = BigInt(1) << 256

    let difficultyEncoder: DifficultyEncoder
    let blockHelper: BlockHelper

    init(encoder: DifficultyEncoder, blockHelper: BlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

    private func work(bits: Int) -> BigInt {
        let target = difficultyEncoder.decodeCompact(bits: bits)
        let bigInt: BigInt = largestHash / (target + 1)
        return bigInt
    }

    private func limit(timeSpan: Int, targetSpacing: Int) -> Int {
        return max(min(288 * targetSpacing, timeSpan), 72 * targetSpacing)
    }

    private func suitableBlock(for block: Block) throws -> Block {
        guard let prevBlock = block.previousBlock, let prevPrevBlock = prevBlock.previousBlock else {
            throw BlockValidatorError.noPreviousBlock
        }
        guard let blockHeader = block.header, let prevBlockHeader = prevBlock.header, let prevPrevBlockHeader = prevPrevBlock.header else {
            throw Block.BlockError.noHeader
        }
        var blockArray = [prevPrevBlock, prevBlock, block]
        // Sorting network.
        if (blockArray[0].header!.timestamp > blockArray[2].header!.timestamp) {
            blockArray.swapAt(0, 2)
        }
        if (blockArray[0].header!.timestamp > blockArray[1].header!.timestamp) {
            blockArray.swapAt(0, 1)
        }
        if (blockArray[1].header!.timestamp > blockArray[2].header!.timestamp) {
            blockArray.swapAt(1, 2)
        }
        return blockArray[1]
    }

    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws {
        guard let candidateHeader = candidate.header else {
            throw Block.BlockError.noHeader
        }
        let lastBlock = try suitableBlock(for: block)
        let firstBlock = try suitableBlock(for: blockHelper.previous(for: block, index: 144)!)
        let heightInterval = lastBlock.height - firstBlock.height

        guard var blocks = blockHelper.previousWindow(for: lastBlock, count: heightInterval - 1) else {
            throw BlockValidatorError.noPreviousBlock
        }
        blocks.append(lastBlock)

        let timeSpan = limit(timeSpan: lastBlock.header!.timestamp - firstBlock.header!.timestamp, targetSpacing: network.targetSpacing)

        var chainWork = BigInt(0)
        for i in 0..<blocks.count {
            chainWork += work(bits: blocks[i].header!.bits)
        }
        let projectedWork = chainWork * BigInt(network.targetSpacing) / BigInt(timeSpan)

        let target = largestHash / projectedWork - BigInt(1)

        let bits = difficultyEncoder.encodeCompact(from: target)

        guard bits == candidateHeader.bits else {
            throw BlockValidatorError.notEqualBits
        }
    }

}
