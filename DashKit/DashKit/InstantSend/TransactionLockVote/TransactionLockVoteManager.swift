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

    func processed(lvHash: Data) -> Bool {
        return relayedLockVotes.first(where: { $0.hash == lvHash }) != nil || checkedLockVotes.first(where: { $0.hash == lvHash }) != nil
    }

    func validate(lockVote: TransactionLockVoteMessage) throws {
        // validate masternode in top 10 masternodes for quorumModifier and has right signature
        try transactionLockVoteValidator.validate(lockVote: lockVote)
    }

}
