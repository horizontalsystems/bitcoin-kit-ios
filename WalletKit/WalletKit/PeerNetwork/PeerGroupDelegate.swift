import Foundation

protocol PeerGroupDelegate : class {
    func peerGroupReady()

    func peerGroupDidReceive(headers: [BlockHeader])
    func peerGroupDidReceive(blockHeader: BlockHeader, withTransactions transactions: [Transaction])
    func peerGroupDidReceive(transaction: Transaction)

    func shouldRequest(inventoryItem: InventoryItem) -> Bool
    func transaction(forHash hash: Data) -> Transaction?
}
