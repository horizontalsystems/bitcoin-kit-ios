import Foundation

protocol PeerGroupDelegate : class {
    func getHeadersHashes() -> [Data]
    func getNonSyncedMerkleBlocksHashes(limit: Int) -> [Data]

    func peerGroupDidReceive(headers: [BlockHeader])
    func peerGroupDidReceive(blockHeader: BlockHeader, withTransactions transactions: [Transaction])
    func peerGroupDidReceive(transaction: Transaction)

    func shouldRequestBlock(hash: Data) -> Bool
    func shouldRequestTransaction(hash: Data) -> Bool

}
