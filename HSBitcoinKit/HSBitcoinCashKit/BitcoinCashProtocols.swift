protocol IBitcoinCashBlockValidatorHelper: IBlockValidatorHelper {
    func medianTimePast(block: Block) throws -> Int
    func suitableBlockIndex(for blocks: [Block]) -> Int?
}