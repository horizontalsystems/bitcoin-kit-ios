public class BlockMedianTimeHelper {
    private let medianTimeSpan = 11
    private let storage: IStorage

    public init(storage: IStorage) {
        self.storage = storage
    }

}

extension BlockMedianTimeHelper: IBlockMedianTimeHelper {

    public var medianTimePast: Int? {
        storage.lastBlock.flatMap { medianTimePast(block: $0) }
    }

    public func medianTimePast(block: Block) -> Int? {
        let startIndex = block.height - medianTimeSpan + 1
        let median = storage.timestamps(from: startIndex, to: block.height)

        if block.height >= medianTimeSpan && median.count < medianTimeSpan {
            return nil
        }

        return median[median.count / 2]
    }

}
