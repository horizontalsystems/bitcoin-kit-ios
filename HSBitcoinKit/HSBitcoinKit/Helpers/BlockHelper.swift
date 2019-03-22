class BlockHelper: IBlockHelper {
    private let medianTimeSpan = 11
    private let storage: IStorage

    init(storage: IStorage) {
        self.storage = storage
    }

    func previous(for block: Block, index: Int) -> Block? {
        return previousWindow(for: block, count: index)?.first
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        guard count > 0 else {
            return nil
        }
        var blocks = [Block]()
        var block = block
        for _ in 0..<count {
            if let prevBlock = block.previousBlock(storage: storage) {
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

}
