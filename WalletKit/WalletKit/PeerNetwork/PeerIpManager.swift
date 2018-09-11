import Foundation

class PeerIpManager {
    let network: NetworkProtocol
    let peerAddresses: [PeerAddress] = [PeerAddress]()
    var hostIndex: Int = -1
    var peerHost: String? {
        hostIndex = hostIndex + 1
        guard network.dnsSeeds.count > hostIndex else {
            return nil
        }
        print("returning: \(network.dnsSeeds[hostIndex])")
        return network.dnsSeeds[hostIndex]
    }


    init(network: NetworkProtocol) {
        self.network = network
    }

    // A PeerAddress holds an IP address representing the network location of
    // a peer in the Peer-to-Peer network.
    class PeerAddress: Equatable {
        var ip: String
        var score: Int = 0
        var using: Bool = false

        init(ip: String, score: Int, using: Bool) {
            self.ip = ip
            self.score = score
            self.using = using
        }

        var hashCode: Int {
            return ip.hash
        }

        static func ==(lhs: PeerAddress, rhs: PeerAddress) -> Bool {
            return lhs.ip == rhs.ip
        }

    }


}
