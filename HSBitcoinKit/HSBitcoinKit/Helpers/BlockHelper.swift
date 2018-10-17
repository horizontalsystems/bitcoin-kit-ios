import Foundation

class BlockHelper {
    static let medianTimeSpan = 11

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
            if let prevBlock = block.previousBlock {
                block = prevBlock
                blocks.insert(block, at: 0)
            } else {
                return nil
            }
        }
        return blocks
    }

    func medianTimePast(block: Block, count: Int = BlockHelper.medianTimeSpan) throws -> Int {
        var median = [Int]()
        var currentBlock = block
        for _ in 0..<count {
            guard let header = currentBlock.header else {
                throw Block.BlockError.noHeader
            }
            median.append(header.timestamp)
            if let prevBlock = currentBlock.previousBlock {
                currentBlock = prevBlock
            } else {
                break
            }
        }
        median.sort()
        guard !median.isEmpty else {
            guard let header = block.header else {
                throw Block.BlockError.noHeader
            }
            return header.timestamp
        }
        return median[median.count / 2]
    }

}
