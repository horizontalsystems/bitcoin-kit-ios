import Foundation
import BigInt

class DAAValidator: IBlockValidator {
//    private let largestHash = BigInt(1) << 256
//    let medianTimeSpanCount = 11
//
    let difficultyEncoder: DifficultyEncoder
    let blockHelper: BlockHelper

    init(encoder: DifficultyEncoder, blockHelper: BlockHelper) {
        difficultyEncoder = encoder
        self.blockHelper = blockHelper
    }

//    private func work(bits: Int) -> BigInt {
//        let target = difficultyEncoder.decodeCompact(bits: bits)
//        let bigInt: BigInt = largestHash / (target + 1)
//        print("work - \(bigInt.description)")
//        return bigInt
//    }
//
//    private func limit(timeSpan: Int, targetSpacing: Int) -> Int {
//        return max(min(288 * targetSpacing, timeSpan), 72 * targetSpacing)
//    }
//
//    private func suitableBlock(for block: Block) throws -> Block {
//        guard let prevBlock = block.previousBlock, let prevPrevBlock = prevBlock.previousBlock else {
//            throw BlockValidatorError.noPreviousBlock
//        }
//        guard let blockHeader = block.header, let prevBlockHeader = prevBlock.header, let prevPrevBlockHeader = prevPrevBlock.header else {
//            throw Block.BlockError.noHeader
//        }
//        var blockArray = [prevPrevBlock, prevBlock, block]
//        // Sorting network.
//        if (blockArray[0].header!.timestamp > blockArray[2].header!.timestamp) {
//            blockArray.swapAt(0, 2)
//        }
//        if (blockArray[0].header!.timestamp > blockArray[1].header!.timestamp) {
//            blockArray.swapAt(0, 1)
//        }
//        if (blockArray[1].header!.timestamp > blockArray[2].header!.timestamp) {
//            blockArray.swapAt(1, 2)
//        }
//        return blockArray[1]
//    }
//// 470804401

    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws {
//        guard let candidateHeader = candidate.header else {
//            throw Block.BlockError.noHeader
//        }
//        let previousBlock = block //try suitableBlock(for: candidate)
//        let firstBlock = try suitableBlock(for: blockHelper.previous(for: block, index: 144)!)
//        let heightInterval = previousBlock.height - firstBlock.height
//
//        guard var blocks = blockHelper.previousWindow(for: candidate, count: heightInterval) else {
//            throw BlockValidatorError.noPreviousBlock
//        }
//        print("FIRST : \(blocks[0].header!.bits)")
//        print("LaST : \(blocks[blocks.count - 1].header!.bits)")
//
//        let timeSpan = limit(timeSpan: blocks[blocks.count - 1].header!.timestamp - blocks[0].header!.timestamp, targetSpacing: network.targetSpacing)
//
//        var chainWork = BigInt(0)
//        for i in 1..<heightInterval {
//            chainWork += work(bits: blocks[i].header!.bits)
//        }
//        let projectedWork = chainWork * BigInt(network.targetSpacing) / BigInt(timeSpan)
//
//        let target = largestHash / projectedWork - BigInt(1)
//        print("TARGET: \(difficultyEncoder.encodeCompact(from: target)) -- candidate: \(candidateHeader.bits)")
//
//        guard difficultyEncoder.encodeCompact(from: target) == candidateHeader.bits else {
//            throw BlockValidatorError.notEqualBits
//        }
    }

}
