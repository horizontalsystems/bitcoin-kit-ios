class BlockHelper: IBlockValidatorHelper {
    private let medianTimeSpan = 11
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func previous(for block: Block, count: Int) -> Block? {
        return previousWindow(for: block, count: count)?.first
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        guard count > 0 else {
            return nil
        }
        var blocks = [Block]()
        var block = block
        for _ in 0..<count {
            if let prevBlock = storage.block(byHashHex: block.previousBlockHashReversedHex) {
                block = prevBlock
                blocks.insert(block, at: 0)
            } else {
                return nil
            }
        }
        return blocks
    }

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

}
