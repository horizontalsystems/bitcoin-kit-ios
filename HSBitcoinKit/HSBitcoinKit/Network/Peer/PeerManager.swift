import Foundation

class PeerManager: IPeerManager {
    private var peers: [IPeer] = []

    func add(peer: IPeer) {
        self.peers.append(peer)
    }

    func peerDisconnected(peer: IPeer) {
        if let index = self.peers.index(where: { $0.equalTo(peer) }) {
            self.peers.remove(at: index)
        }
    }

    func disconnectAll() {
        for peer in peers {
            peer.disconnect(error: nil)
        }
    }

    func totalPeersCount() -> Int {
        return peers.count
    }

    func someReadyPeers() -> [IPeer] {
        let readyPeers = peers.filter({ $0.ready })

        if readyPeers.count == 0 {
            return [IPeer]()
        }

        if readyPeers.count == 1 {
            return readyPeers
        }

        return Array(readyPeers.prefix(readyPeers.count / 2))
    }

    func connected() -> [IPeer] {
        return peers.filter({ $0.connected })
    }

    func nonSyncedPeer() -> IPeer? {
        return peers.first(where: { $0.connected && !$0.synced })
    }

    func halfIsSynced() -> Bool {
        let syncedPeersCount = peers.filter({ $0.connected && $0.synced }).count

        return syncedPeersCount >= peers.count / 2
    }

}
