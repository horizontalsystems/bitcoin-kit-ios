import Foundation

class GetBlockHashesTask: PeerTask {

    var blockHashes = [Data]()
    private var blockLocatorHashes: [Data]
    private var pingNonce: UInt64

    init(hashes: [Data], pingNonce: UInt64 = UInt64.random(in: 0..<UINT64_MAX)) {
        self.blockLocatorHashes = hashes
        self.pingNonce = pingNonce
    }

    override func start() {
        requester?.getBlocks(hashes: blockLocatorHashes)
        requester?.ping(nonce: pingNonce)
    }

    override func handle(items: [InventoryItem]) -> Bool {
        let newHashes = items
                .filter { item in return item.objectType == .blockMessage }
                .map { item in return item.hash }

        for hash in newHashes {
            if blockLocatorHashes.contains(hash) {
                // If peer sends us a hash which we have in blockLocatorHashes, it means it's just a stale block hash.
                // Because, otherwise it doesn't conform with P2P protocol
                return true
            }
        }

        if blockHashes.count < newHashes.count {
            blockHashes = newHashes
        }

        return !newHashes.isEmpty
    }

    override func handle(pongNonce: UInt64) -> Bool {
        if pongNonce == pingNonce {
            delegate?.handle(completedTask: self)
            return true
        }

        return false
    }
}

extension GetBlockHashesTask: Equatable {

    static func ==(lhs: GetBlockHashesTask, rhs: GetBlockHashesTask) -> Bool {
        return lhs.blockLocatorHashes == rhs.blockLocatorHashes
    }

}
