public class DashKitErrors {

    public enum LockVoteValidation: Error {
        case masternodeNotFound
        case masternodeNotInTop
        case txInputNotFound
        case signatureNotValid
    }

    public enum InstantSendLockValidation: Error {
        case signatureNotValid
    }

    enum MasternodeListValidation: Error {
        case wrongMerkleRootList
        case wrongCoinbaseHash
        case noMerkleBlockHeader
        case wrongMerkleRoot
    }

    enum QuorumListValidation: Error {
        case wrongMerkleRootList
    }


}
