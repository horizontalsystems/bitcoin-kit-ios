import Foundation
import RealmSwift

class PeerIpManager {
    let network: NetworkProtocol
    let realmFactory: RealmFactory
    let queue: DispatchQueue
    var collecting: Bool = false
    var connectedHosts: [String] = []
    weak var delegate: PeerIpManagerDelegate?

    var peerHost: String? {
        let realm = realmFactory.realm
        let addresses = realm.objects(PeerAddress.self).sorted(byKeyPath: "score")

        let peerAddress = addresses.first(where: { !connectedHosts.contains($0.ip) })

        if let peerAddress = peerAddress {
            connectedHosts.append(peerAddress.ip)
        } else {
            collectPeerHosts()
        }

        return peerAddress?.ip
    }

    init(network: NetworkProtocol, realmFactory: RealmFactory) {
        self.network = network
        self.realmFactory = realmFactory
        queue = DispatchQueue(label: "PeerIpManager Queue", qos: .background)
    }

    func hostDisconnected(host: String, withError error: Bool) {
        if let index = connectedHosts.index(of: host) {
            connectedHosts.remove(at: index)
        }

        let realm = realmFactory.realm
        if let peerAddress = realm.objects(PeerAddress.self).filter("ip = %@", host).first {
            do {
                try realm.write {
                    if error {
                        realm.delete(peerAddress)
                    } else {
                        peerAddress.score += 1
                    }
                }
            } catch {
                Logger.shared.log(self, "could not process IP due to error: \(error)")
            }
        }
    }

    private func collectPeerHosts() {
        guard !collecting else {
            return
        }
        collecting = true

        queue.async {
            var newHosts = [String]()
            for dnsSeed in self.network.dnsSeeds {
                newHosts.append(contentsOf: self.lookup(dnsSeed: dnsSeed))
            }

            self.addPeers(hosts: newHosts)
            self.collecting = false
        }
    }

    func addPeers(hosts: [String]) {
        let realm = self.realmFactory.realm
        let existingPeerAddresses = realm.objects(PeerAddress.self)

        let newPeerAddresses = hosts
                .filter({ ip in !existingPeerAddresses.contains(where: { peerAddress in peerAddress.ip == ip }) })
                .reduce(into: []) {
                    uniqueElements, element in

                    if !uniqueElements.contains(element) {
                        uniqueElements.append(element)
                    }
                }
                .map({ ip in PeerAddress(ip: ip, score: 0) })

        guard !hosts.isEmpty else {
            return
        }

        do {
            Logger.shared.log(self, "Adding new hosts: \(newPeerAddresses.count)")
            try realm.write {
                realm.add(newPeerAddresses)
            }
        } catch {
            Logger.shared.log(self, "could not add PeerAddresses due to error: \(error)")
        }

        self.delegate?.newHostsAdded()
    }

    private func lookup(dnsSeed: String) -> [String] {
        let hostRef = CFHostCreateWithName(kCFAllocatorDefault, dnsSeed as CFString).takeRetainedValue()
        let resolved = CFHostStartInfoResolution(hostRef, CFHostInfoType.addresses, nil)
        var resolvedDarwin = DarwinBoolean(resolved)
        let optionalDataArray = CFHostGetAddressing(hostRef, &resolvedDarwin)?.takeUnretainedValue()
        var ips = [String]()

        if let dataArray = optionalDataArray {
            for address in (dataArray as NSArray) {
                if let address = address as? Data {
                    let s = address.hex.dropFirst(8).prefix(8)
                    if let ipPart1 = UInt8(String(s.prefix(2)), radix: 16),
                       let ipPart2 = UInt8(String(s.dropFirst(2).prefix(2)), radix: 16),
                       let ipPart3 = UInt8(String(s.dropFirst(4).prefix(2)), radix: 16),
                       let ipPart4 = UInt8(String(s.dropFirst(6)), radix: 16) {
                        ips.append("\(ipPart1).\(ipPart2).\(ipPart3).\(ipPart4)")
                    }
                }
            }

        }

        return ips
    }

}

protocol PeerIpManagerDelegate: class {
    var peerCount: Int { get set }
    func newHostsAdded()
}
