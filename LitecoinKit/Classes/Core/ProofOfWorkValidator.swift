import Foundation
import BitcoinCore
import BigInt

class ProofOfWorkValidator: IBlockValidator {
    private let hasher: IHasher
    private let difficultyEncoder: IDifficultyEncoder

    init(hasher: IHasher, difficultyEncoder: IDifficultyEncoder) {
        self.hasher = hasher
        self.difficultyEncoder = difficultyEncoder
    }

    private func serializeHeader(block: Block) -> Data {
        var data = Data()

        data.append(Data(from: UInt32(block.version)))
        data += block.previousBlockHash
        data += block.merkleRoot
        data.append(Data(from: UInt32(block.timestamp)))
        data.append(Data(from: UInt32(block.bits)))
        data.append(Data(from: UInt32(block.nonce)))

        return data
    }

    func validate(block: Block, previousBlock: Block) throws {
        let header = serializeHeader(block: block)
        let hash = hasher.hash(data: header)

        guard (difficultyEncoder.compactFrom(hash: hash) < block.bits) else {
            throw BitcoinCoreErrors.BlockValidation.invalidProofOfWork
        }
    }

}
