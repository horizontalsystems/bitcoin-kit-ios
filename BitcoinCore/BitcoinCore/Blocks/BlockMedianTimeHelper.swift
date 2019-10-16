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

    // Returns (an approximate medianTimePast of a block in which given transaction is included) PLUS ~1 hour.
    // This is not an accurate medianTimePast, it always returns a timestamp nearly 7 blocks ahead.
    // But this is quite enough in our case since we're setting relative time-locks for at least 1 month
    public func medianTimePast(transactionHash: Data) -> Int? {
        guard let transaction = storage.transaction(byHash: transactionHash) else {
            return nil
        }

        return transaction.timestamp
    }

}
