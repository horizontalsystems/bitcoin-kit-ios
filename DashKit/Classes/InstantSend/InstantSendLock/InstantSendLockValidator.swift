import BlsKit

class InstantSendLockValidator: IInstantSendLockValidator {
    private let quorumListManager: IQuorumListManager
    private let hasher: IDashHasher

    init(quorumListManager: QuorumListManager, hasher: IDashHasher) {
        self.quorumListManager = quorumListManager
        self.hasher = hasher
    }

    func validate(isLock: ISLockMessage) throws {
        // 01. Get quorum for islock requestID
        let quorum = try quorumListManager.quorum(for: isLock.requestID, type: QuorumType.quorum50_60)

        // 02. Make signId data to verify signature
        var signId = quorum.typeWithQuorumHash +
                        isLock.requestID +
                        isLock.txHash
        signId = hasher.hash(data: signId)

        // 03. Verify signature by BLS
        let verified = BlsKit.Kit.verify(messageDigest: signId, pubKey: quorum.quorumPublicKey, signature: isLock.sign)

        guard verified else {
            throw DashKitErrors.ISLockValidation.signatureNotValid
        }
    }

}
