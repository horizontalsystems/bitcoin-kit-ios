import BitcoinCore
import BigInt

class ASERTValidator: IBlockChainedValidator, IBitcoinCashBlockValidator {
    private let anchorBlockHeight = 661647
    private let anchorParentBlockTime = 1605447844            // 2020 November 15, 14:13 GMT
    private let anchorBlockBits = 0x1804dafe
    private let anchorBlockTarget: BigInt

    private let idealBlockTime = 600
    private let halfLife = 172800                               // 2 days (in seconds) on mainnet
    private let radix: BigInt = 65536                           // pow(2, 16) , 16 bits for decimal part of fixed-point integer arithmetic
    private let maxBits = 0x1d00ffff                            // maximum target in bits representation
    private let maxTarget: BigInt                               // maximum target as integer

    private let difficultyEncoder: IDifficultyEncoder

    init(encoder: IDifficultyEncoder) {
        difficultyEncoder = encoder
        maxTarget = difficultyEncoder.decodeCompact(bits: maxBits)
        anchorBlockTarget = difficultyEncoder.decodeCompact(bits: anchorBlockBits)
    }

    func nextTarget(timestamp: Int, height: Int) -> Int {
        let timeDelta = timestamp - anchorParentBlockTime
        let heightDelta = height - anchorBlockHeight

        var exponent = timeDelta - idealBlockTime * (heightDelta + 1)
        exponent <<= 16
        exponent /= halfLife

        let numShifts = exponent >> 16

        exponent -= numShifts << 16
        let bigIntExponent = BigInt(exponent)

        var factor = BigInt(195766423245049) * bigIntExponent +
                BigInt(971821376) * bigIntExponent.power(2) +
                BigInt(5127) * bigIntExponent.power(3) +
                BigInt(2).power(47)

        factor >>= 48
        factor += radix
        var nextTarget = anchorBlockTarget * factor

        if numShifts < 0 {
            nextTarget >>= abs(numShifts)
        } else {
            nextTarget <<= numShifts
        }

        nextTarget >>= 16
        if nextTarget == 0 {
            return difficultyEncoder.encodeCompact(from: 1)
        }
        if nextTarget > maxTarget {
            return maxBits
        }

        return difficultyEncoder.encodeCompact(from: nextTarget)
    }

    func validate(block: Block, previousBlock: Block) throws {
        guard nextTarget(timestamp: previousBlock.timestamp, height: previousBlock.height) == block.bits else {
            throw BitcoinCoreErrors.BlockValidation.notEqualBits
        }
    }

    func isBlockValidatable(block: Block, previousBlock: Block) -> Bool {
        previousBlock.height >= anchorBlockHeight
    }

}
