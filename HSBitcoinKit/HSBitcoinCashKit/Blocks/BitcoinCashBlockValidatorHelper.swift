class BitcoinCashBlockValidatorHelper: BlockValidatorHelper, IBitcoinCashBlockValidatorHelper {
    private let medianTimeSpan = 11

    func medianTimePast(block: Block) throws -> Int {
        var median = [Int]()
        var currentBlock = block
        for _ in 0..<medianTimeSpan {
            median.append(currentBlock.timestamp)
            if let prevBlock = storage.block(byHashHex: currentBlock.previousBlockHashReversedHex) {
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

    func suitableBlockIndex(for blocks: [Block]) -> Int? {         // works just for 3 blocks
        guard blocks.count == 3 else {
            return nil
        }
        let suitableBlock = blocks.sorted(by: { $1.timestamp > $0.timestamp })[1]

        return blocks.firstIndex(where: { $0.height == suitableBlock.height })
    }

}
