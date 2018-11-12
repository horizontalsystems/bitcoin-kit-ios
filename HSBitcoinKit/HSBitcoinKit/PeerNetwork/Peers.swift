import Foundation

class Peers: IPeers {
    private var connectedPeers: [IPeer] = []
    private var connectingPeers: [IPeer] = []

    var syncPeer: IPeer?

    init() {
    }

    func add(peer: IPeer) {
        self.connectingPeers.append(peer)
    }

    func peerConnected(peer: IPeer) {
        if let index = self.connectingPeers.index(where: { $0.equalTo(peer) }) {
            self.connectingPeers.remove(at: index)
        }
        self.connectedPeers.append(peer)
    }

    func peerDisconnected(peer: IPeer) {
        if let index = self.connectedPeers.index(where: { $0.equalTo(peer) }) {
            self.connectedPeers.remove(at: index)
        }
    }

    func disconnectAll() {
        for peer in connectedPeers {
            peer.disconnect(error: nil)
        }

        for peer in connectingPeers {
            peer.disconnect(error: nil)
        }
    }

    func totalPeersCount() -> Int {
        return connectedPeers.count + connectingPeers.count
    }

    func someReadyPeers() -> [IPeer] {
        let readyPeers = connectedPeers.filter({ $0.ready })

        if readyPeers.count == 0 {
            return [IPeer]()
        }

        if readyPeers.count == 1 {
            return readyPeers
        }

        return Array(readyPeers.prefix(readyPeers.count / 2))
    }

    func connected() -> [IPeer] {
        return connectedPeers
    }

    func nonSyncedPeer() -> IPeer? {
        return connectedPeers.first(where: { !$0.synced })
    }

    func syncPeerIs(peer: IPeer) -> Bool {
        return peer.equalTo(syncPeer)
    }
}
