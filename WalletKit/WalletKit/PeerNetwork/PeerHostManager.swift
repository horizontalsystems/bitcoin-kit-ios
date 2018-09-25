import Foundation
import RealmSwift

class PeerHostManager {
    let network: NetworkProtocol
    let realmFactory: RealmFactory
    let hostDiscovery: HostDiscovery
    private let dnsLookupQueue: DispatchQueue
    private let localQueue: DispatchQueue
    private var collecting: Bool = false
    private var connectedHosts: [String] = []
    weak var delegate: PeerHostManagerDelegate?

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

    init(network: NetworkProtocol, realmFactory: RealmFactory, hostDiscovery: HostDiscovery = HostDiscovery(),
         dnsLookupQueue: DispatchQueue = DispatchQueue(label: "PeerHostManager Queue", qos: .background, attributes: .concurrent),
         localQueue: DispatchQueue = DispatchQueue(label: "PeerHostManager Queue", qos: .utility)) {
        self.network = network
        self.realmFactory = realmFactory
        self.hostDiscovery = hostDiscovery
        self.dnsLookupQueue = dnsLookupQueue
        self.localQueue = localQueue
    }

    func hostDisconnected(host: String, withError error: Bool) {
        localQueue.async {
            self.connectedHosts.removeAll(where: { connectedHost in connectedHost == host })

            let realm = self.realmFactory.realm
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
    }

    private func collectPeerHosts() {
        guard !collecting else {
            return
        }
        collecting = true
        let dispatchGroup = DispatchGroup()

        for dnsSeed in self.network.dnsSeeds {
            dispatchGroup.enter()
            dnsLookupQueue.async {
                self.addHosts(hosts: self.hostDiscovery.lookup(dnsSeed: dnsSeed))
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: dnsLookupQueue) {
            self.collecting = false
        }
    }

    func addHosts(hosts: [String]) {
        localQueue.async {
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
    }

}

protocol PeerHostManagerDelegate: class {
    func newHostsAdded()
}
