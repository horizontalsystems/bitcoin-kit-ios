public class DashKitErrors {

    public enum LockVoteValidation: Error {
        case masternodeNotFound
        case masternodeNotInTop
        case txInputNotFound
    }

}
