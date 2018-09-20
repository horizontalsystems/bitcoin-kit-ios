import Foundation

enum BlockValidatorError: Error {
    case noCheckpointBlock
    case noPreviousBlock
    case wrongPreviousHeaderHash
    case notEqualBits
    case notDifficultyTransitionEqualBits
}

protocol IBlockValidator: class {
    func validate(candidate: Block, block: Block, network: NetworkProtocol) throws
}