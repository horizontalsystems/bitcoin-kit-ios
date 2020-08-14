import Foundation

class PeerManager: IPeerManager {
    private var peers: [IPeer] = []

    var totalPeersCount: Int {
        peers.count
    }

    var connected: [IPeer] {
        peers.filter({ $0.connected })
    }

    var sorted: [IPeer] {
        connected.sorted(by: { $0.connectionTime < $1.connectionTime })
    }

    var readyPeers: [IPeer] {
        peers.filter { $0.connected && $0.ready }
    }

    func add(peer: IPeer) {
        self.peers.append(peer)
    }

    func peerDisconnected(peer: IPeer) {
        if let index = self.peers.firstIndex(where: { $0.equalTo(peer) }) {
            self.peers.remove(at: index)
        }
    }

    func disconnectAll() {
        for peer in peers {
            peer.disconnect(error: nil)
        }
    }

}
