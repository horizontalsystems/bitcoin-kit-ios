import BitcoinCore

struct TransactionLockVoteMessage: IMessage {
    let command: String = "txlvote"

    //  TXID of the transaction to lock
    let txHash: Data
    //  The unspent outpoint to lock in this transaction
    let outpoint: Outpoint
    //  The outpoint of the masternode which is signing the vote
    let outpointMasternode: Outpoint
    //  Added in protocol version 70213. Only present when Spork 15 is active.
    let quorumModifierHash: Data
    //  The proTxHash of the DIP3 masternode which is signing the vote
    let masternodeProTxHash: Data
    //  Masternode BLS signature
    let vchMasternodeSignature: Data

    let hash: Data

}

extension TransactionLockVoteMessage: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
    }

    public static func ==(lhs: TransactionLockVoteMessage, rhs: TransactionLockVoteMessage) -> Bool {
        return lhs.hash == rhs.hash
    }

}
