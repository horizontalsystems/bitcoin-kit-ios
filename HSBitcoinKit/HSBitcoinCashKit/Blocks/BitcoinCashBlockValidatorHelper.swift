class BitcoinCashBlockValidatorHelper: BlockValidatorHelper, IBitcoinCashBlockValidatorHelper {
    private let medianTimeSpan = 11
    private let bitcoinCashStorage: IBitcoinCashStorage

    init(storage: IBitcoinCashStorage) {
        bitcoinCashStorage = storage

        super.init(storage: storage)
    }

    func medianTimePast(block: Block) -> Int {
        let startIndex = block.height - medianTimeSpan + 1
        var median = bitcoinCashStorage.timestamps(from: startIndex, to: block.height, ascending: true)
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
