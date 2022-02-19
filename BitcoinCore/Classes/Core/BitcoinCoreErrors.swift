import Foundation

public class BitcoinCoreErrors {

    public enum AddressConversion: Error {
        case invalidChecksum
        case invalidAddressLength
        case unknownAddressType
        case wrongAddressPrefix
    }

    public enum TransactionSendError: Error {
        case noConnectedPeers
        case peersNotSynced
    }

    public enum MerkleBlockValidation: Error {
        case noMerkleBranch
        case wrongMerkleRoot
        case noTransactions
        case tooManyTransactions
        case moreHashesThanTransactions
        case matchedBitsFewerThanHashes
        case unnecessaryBits
        case notEnoughBits
        case notEnoughHashes
        case duplicatedLeftOrRightBranches
    }

    public enum BlockValidation: Error {
        case noCheckpointBlock
        case noPreviousBlock
        case wrongPreviousHeader
        case wrongHeaderHash
        case notEqualBits
        case notDifficultyTransitionEqualBits
        case invalidProofOfWork
    }

    public enum MessageSerialization: Error {
        case noMessageSerializer
    }

    public enum ScriptBuild: Error {
        case wrongType
        case unknownType
    }

    public struct AddressConversionErrors: Error {
        let errors: [Error]
    }

    public enum SendValueErrors: Error {
        case dust
        case emptyOutputs
        case singleNoChangeOutputNotFound
        case notEnough
    }

    public enum Unexpected: Error {
        case unknown
    }


}
