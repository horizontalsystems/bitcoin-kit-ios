protocol IBitcoinCashBlockValidatorHelper: IBlockValidatorHelper {
    func medianTimePast(block: Block) -> Int
    func suitableBlockIndex(for blocks: [Block]) -> Int?
}

protocol IBitcoinCashStorage: IStorage {
    func timestamps(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Int]
}