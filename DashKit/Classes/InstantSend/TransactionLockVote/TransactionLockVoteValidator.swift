import BitcoinCore
import BlsKit

class TransactionLockVoteValidator: ITransactionLockVoteValidator {
    private let storage: IDashStorage
    private let hasher: IDashHasher

    private let totalSignatures: Int

    init(storage: IDashStorage, hasher: IDashHasher, totalSignatures: Int = 10) {
        self.storage = storage
        self.hasher = hasher
        self.totalSignatures = totalSignatures
    }

    func validate(lockVote: TransactionLockVoteMessage) throws {
        let masternodes = storage.masternodes.filter { $0.isValid }

        var quorumMasternodes = [QuorumMasternode]()

        // 1. Make list of masternodes with quorumHashes
        masternodes.forEach { masternode in

            let quorumHash = Data(hasher.hash(data: masternode.confirmedHashWithProRegTxHash + lockVote.quorumModifierHash).reversed()) //Score calculated for littleEndiad (check last bytes, then previous and ...)

            quorumMasternodes.append(QuorumMasternode(quorumHash: quorumHash, masternode: masternode))
        }

        // 2. Sort descending
        quorumMasternodes.sort(by: >)

        // 3. Find index for masternode
        guard let index = quorumMasternodes.firstIndex(where: { $0.masternode.proRegTxHash == lockVote.masternodeProTxHash }) else {
            throw DashKitErrors.LockVoteValidation.masternodeNotFound
        }

        // 4. Check masternode in first 10 scores
        guard index < totalSignatures else {
            throw DashKitErrors.LockVoteValidation.masternodeNotInTop
        }

        // 5. Check signature of masternode
        let masternode = quorumMasternodes[index].masternode
        if !BlsKit.Kit.verify(messageDigest: lockVote.hash, pubKey: masternode.pubKeyOperator, signature: lockVote.vchMasternodeSignature) {
            throw DashKitErrors.LockVoteValidation.signatureNotValid
        }
    }

}
