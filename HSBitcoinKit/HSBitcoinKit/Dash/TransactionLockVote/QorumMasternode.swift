class QuorumMasternode {
    let quorumHash: Data
    let masternode: Masternode

    init(quorumHash: Data, masternode: Masternode) {
        self.quorumHash = quorumHash
        self.masternode = masternode
    }

}

extension QuorumMasternode: Hashable, Comparable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(quorumHash)
    }

    public static func ==(lhs: QuorumMasternode, rhs: QuorumMasternode) -> Bool {
        return lhs.quorumHash == rhs.quorumHash
    }

    public static func <(lhs: QuorumMasternode, rhs: QuorumMasternode) -> Bool {
        return lhs.quorumHash < rhs.quorumHash
    }

}
