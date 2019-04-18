import Foundation

enum BlockValidatorError: Error {
    case noCheckpointBlock
    case noPreviousBlock
    case wrongPreviousHeaderHash
    case notEqualBits
    case notDifficultyTransitionEqualBits
    case invalidProofOfWork
}
