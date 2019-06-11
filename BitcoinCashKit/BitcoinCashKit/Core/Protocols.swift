import BitcoinCore
import BigInt

// BitcoinCore Compatibility

protocol IBitcoinCashDifficultyEncoder {
    func decodeCompact(bits: Int) -> BigInt
    func encodeCompact(from bigInt: BigInt) -> Int
}

protocol IBitcoinCashHasher {
    func hash(data: Data) -> Data
}

protocol IBitcoinCashBlockValidator {
    func validate(block: Block, previousBlock: Block) throws
    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool
}

// ###############################

protocol IBitcoinCashBlockValidatorHelper {
    func medianTimePast(block: Block) -> Int
    func suitableBlockIndex(for blocks: [Block]) -> Int?

    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

protocol IBitcoinCashStorage {
    func timestamps(from startHeight: Int, to endHeight: Int, ascending: Bool) -> [Int]

    func block(byHash: Data) -> Block?
}

protocol IBlockValidatorHelperWrapper {
    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}
