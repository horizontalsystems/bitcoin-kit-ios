import BitcoinCore

class BitcoinCashBlockValidatorHelper: IBitcoinCashBlockValidatorHelper {
    private let coreBlockValidatorHelper: IBlockValidatorHelperWrapper

    init(coreBlockValidatorHelper: IBlockValidatorHelperWrapper) {
        self.coreBlockValidatorHelper = coreBlockValidatorHelper
    }

    func suitableBlockIndex(for blocks: [Block]) -> Int? {         // works just for 3 blocks
        guard blocks.count == 3 else {
            return nil
        }
        let suitableBlock = blocks.sorted(by: { $1.timestamp > $0.timestamp })[1]

        return blocks.firstIndex(where: { $0.height == suitableBlock.height })
    }

    func previous(for block: Block, count: Int) -> Block? {
        coreBlockValidatorHelper.previous(for: block, count: count)
    }

    func previousWindow(for block: Block, count: Int) -> [Block]? {
        coreBlockValidatorHelper.previousWindow(for: block, count: count)
    }

}
