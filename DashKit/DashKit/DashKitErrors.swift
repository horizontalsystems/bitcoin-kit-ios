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

}
