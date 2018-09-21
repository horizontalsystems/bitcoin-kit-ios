import Foundation

protocol PeerGroupDelegate : class {
    func getHeadersHashes() -> [Data]
    func getNonSyncedMerkleBlocksHashes() -> [Data]
    func getNonSentTransactions() -> [Transaction]

    func peerGroupDidReceive(headers: [BlockHeader])
    func peerGroupDidReceive(merkleBlocks: [MerkleBlock])
    func peerGroupDidReceive(transaction: Transaction)

    func shouldRequestBlock(hash: Data) -> Bool
    func shouldRequestTransaction(hash: Data) -> Bool

}
