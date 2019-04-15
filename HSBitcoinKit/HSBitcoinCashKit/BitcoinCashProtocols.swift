protocol IBitcoinCashBlockValidatorHelper: IBlockValidatorHelper {
    func medianTimePast(block: Block) throws -> Int
    func suitableBlock(for block: Block) throws -> Block
}