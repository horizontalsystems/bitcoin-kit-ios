class BitcoinCashBlockValidatorHelper: BlockValidatorHelper, IBitcoinCashBlockValidatorHelper {
    private let medianTimeSpan = 11

    func medianTimePast(block: Block) throws -> Int {
        var median = [Int]()
        var currentBlock = block
        for _ in 0..<medianTimeSpan {
            median.append(currentBlock.timestamp)
            if let prevBlock = currentBlock.previousBlock(storage: storage) {
                currentBlock = prevBlock
            } else {
                break
            }
        }
        median.sort()
        guard !median.isEmpty else {
            return block.timestamp
        }
        return median[median.count / 2]
    }

    func suitableBlock(for block: Block) throws -> Block {
        var blockArray = [(timestamp: Int, block: Block)]()
        var currentBlock = block
        for _ in 0..<3 {
            blockArray.append((timestamp: currentBlock.timestamp, block: currentBlock))
            guard let prevBlock = previous(for: currentBlock, count: 1) else {
                throw BitcoinCoreErrors.BlockValidation.noPreviousBlock
            }
            currentBlock = prevBlock
        }
        blockArray.sort { $0.timestamp <= $1.timestamp }
        return blockArray[1].block
    }

}
