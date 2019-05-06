import BitcoinCore


class TransactionLockVoteManager: ITransactionLockVoteManager {
    private let transactionLockVoteValidator: ITransactionLockVoteValidator

    private(set) var relayedLockVotes = Set<TransactionLockVoteMessage>()
    private(set) var checkedLockVotes = Set<TransactionLockVoteMessage>()

    init(transactionLockVoteValidator: ITransactionLockVoteValidator) {
        self.transactionLockVoteValidator = transactionLockVoteValidator
    }

    func takeRelayedLockVotes(for txHash: Data) -> [TransactionLockVoteMessage] {
        let votes = relayedLockVotes.filter {
            $0.txHash == txHash
        }
        relayedLockVotes.subtract(votes)
        return Array(votes).sorted { $0.hash < $1.hash }
    }

    func add(relayed: TransactionLockVoteMessage) {
        relayedLockVotes.insert(relayed)
    }

    func add(checked: TransactionLockVoteMessage) {
        checkedLockVotes.insert(checked)
    }

    func removeCheckedLockVotes(for txHash: Data) {
        remove(from: &checkedLockVotes, txHash: txHash)
    }

    func clean() {
        checkedLockVotes.removeAll()
        relayedLockVotes.removeAll()
    }

    func processed(lvHash: Data) -> Bool {
        return relayedLockVotes.first(where: { $0.hash == lvHash }) != nil || checkedLockVotes.first(where: { $0.hash == lvHash }) != nil
    }

    private func remove(from set: inout Set<TransactionLockVoteMessage>, txHash: Data) {
        var removingSet = Set<TransactionLockVoteMessage>()
        set.forEach {
            if $0.txHash == txHash {
                removingSet.insert($0)
            }
        }
        set.subtract(removingSet)
    }

    func validate(lockVote: TransactionLockVoteMessage) throws {
        // validate masternode in top 10 masternodes for quorumModifier
        try transactionLockVoteValidator.validate(quorumModifierHash: lockVote.quorumModifierHash, masternodeProTxHash: lockVote.masternodeProTxHash)
    }

}
