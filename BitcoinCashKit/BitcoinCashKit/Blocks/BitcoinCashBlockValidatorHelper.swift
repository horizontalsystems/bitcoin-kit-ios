import BitcoinCore

class BitcoinCashBlockValidatorHelper: IBitcoinCashBlockValidatorHelper {
    private let medianTimeSpan = 11
    private let bitcoinCashStorage: IBitcoinCashStorage
    private let coreBlockValidatorHelper: IBlockValidatorHelperWrapper

    init(storage: IBitcoinCashStorage, coreBlockValidatorHelper: IBlockValidatorHelperWrapper) {
        bitcoinCashStorage = storage
        self.coreBlockValidatorHelper = coreBlockValidatorHelper
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

    func previous(for block: Block, count: Int) -> Block? {
        return coreBlockValidatorHelper.previous(for: block, count: count)
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        return coreBlockValidatorHelper.previousWindow(for: block, count: count)
    }

}
