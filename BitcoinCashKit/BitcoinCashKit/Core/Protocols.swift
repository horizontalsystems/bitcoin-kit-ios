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
    func suitableBlockIndex(for blocks: [Block]) -> Int?

    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

protocol IBlockValidatorHelperWrapper {
    func previous(for block: Block, count: Int) -> Block?
    func previousWindow(for block: Block, count: Int) -> [Block]?
}

protocol IBitcoinCashBlockMedianTimeHelper {
    var medianTimePast: Int? { get }
    func medianTimePast(block: Block) -> Int?
}