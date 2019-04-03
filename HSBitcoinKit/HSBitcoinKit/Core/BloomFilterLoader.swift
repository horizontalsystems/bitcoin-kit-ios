class BloomFilterLoader: IPeerGroupListener, IBloomFilterManagerDelegate {
    private let bloomFilterManager: IBloomFilterManager
    private var peers = [IPeer]()

    init(bloomFilterManager: IBloomFilterManager) {
        self.bloomFilterManager = bloomFilterManager
    }

    func onPeerConnect(peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
        peers.append(peer)
    }

    func onPeerDisconnect(peer: IPeer, error: Error?) {
        if let index = peers.firstIndex(where: { $0.equalTo(peer) }) {
            peers.remove(at: index)
        }
    }

    func bloomFilterUpdated(bloomFilter: BloomFilter) {
        peers.forEach { peer in
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

}
