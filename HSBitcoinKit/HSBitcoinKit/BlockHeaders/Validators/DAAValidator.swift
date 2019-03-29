import BigInt

class DAAValidator: IBlockValidator {
    private let storage: IStorage
    private let largestHash = BigInt(1) << 256

    let difficultyEncoder: IDifficultyEncoder
    let blockHelper: IBlockHelper

    init(storage: IStorage, encoder: IDifficultyEncoder, blockHelper: IBlockHelper) {
        self.storage = storage
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
        var blockArray = [(timestamp: Int, block: Block)]()
        var currentBlock = block
        for _ in 0..<3 {
            blockArray.append((timestamp: currentBlock.timestamp, block: currentBlock))
            guard let prevBlock = currentBlock.previousBlock(storage: storage) else {
                throw BlockValidatorError.noPreviousBlock
            }
            currentBlock = prevBlock
        }
        blockArray.sort { $0.timestamp <= $1.timestamp }
        return blockArray[1].block
    }

    func validate(candidate: Block, block: Block, network: INetwork) throws {
        let lastBlock = try suitableBlock(for: block)
        let firstBlock = try suitableBlock(for: blockHelper.previous(for: block, index: 144)!)
        let heightInterval = lastBlock.height - firstBlock.height

        guard var blocks = blockHelper.previousWindow(for: lastBlock, count: heightInterval - 1) else {
            throw BlockValidatorError.noPreviousBlock
        }
        blocks.append(lastBlock)

        let timeSpan = limit(timeSpan: lastBlock.timestamp - firstBlock.timestamp, targetSpacing: network.targetSpacing)

        var chainWork = BigInt(0)
        for i in 0..<blocks.count {
            chainWork += work(bits: blocks[i].bits)
        }
        let projectedWork = chainWork * BigInt(network.targetSpacing) / BigInt(timeSpan)

        let target = largestHash / projectedWork - BigInt(1)

        let bits = difficultyEncoder.encodeCompact(from: target)

        guard bits == candidate.bits else {
            throw BlockValidatorError.notEqualBits
        }
    }

}
