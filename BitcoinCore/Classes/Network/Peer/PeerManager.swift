import Foundation

class PeerManager: IPeerManager {
    private var peers: [IPeer] = []

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

    func totalPeersCount() -> Int {
        return peers.count
    }

    func connected() -> [IPeer] {
        return peers.filter({ $0.connected })
    }

    func sorted() -> [IPeer] {
        return connected().sorted(by: { $0.connectionTime < $1.connectionTime })
    }

}
