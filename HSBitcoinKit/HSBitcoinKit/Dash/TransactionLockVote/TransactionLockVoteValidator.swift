import HSCryptoKit

class TransactionLockVoteValidator: ITransactionLockVoteValidator {
    private static let totalSignatures = 10

    private let storage: IDashStorage
    private let hasher: IHasher

    init(storage: IDashStorage, hasher: IHasher) {
        self.storage = storage
        self.hasher = hasher
    }

    func validate(quorumModifierHash: Data, masternodeProTxHash: Data) throws {
        let masternodes = storage.masternodes.filter { $0.isValid }

        var quorumMasternodes = [QuorumMasternode]()

        // 1. Make list of masternodes with quorumHashes
        masternodes.forEach { masternode in

            let quorumHash = Data(hasher.hash(data: hasher.hash(data: masternode.proRegTxHash + masternode.confirmedHash) + quorumModifierHash).reversed()) //Score calculated for littleEndiad (check last bytes, then previous and ...)

            quorumMasternodes.append(QuorumMasternode(quorumHash: quorumHash, masternode: masternode))
        }

        // 2. Sort descending
        quorumMasternodes.sort(by: >)

        // 3. Find index for masternode
        guard let index = quorumMasternodes.firstIndex(where: { $0.masternode.proRegTxHash == masternodeProTxHash }) else {
            print("DashKitErrors.LockVoteValidation.masternodeNotFound")
            throw DashKitErrors.LockVoteValidation.masternodeNotFound
        }

        // 4. Check masternode in first 10 scores
        guard (index + 1) < TransactionLockVoteValidator.totalSignatures else {
            print("DashKitErrors.LockVoteValidation.masternodeNotInTop")
            throw DashKitErrors.LockVoteValidation.masternodeNotInTop
        }

    }

}
