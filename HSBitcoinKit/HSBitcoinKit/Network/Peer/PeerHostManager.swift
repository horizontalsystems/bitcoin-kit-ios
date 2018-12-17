import RealmSwift

class PeerHostManager {
    private let network: INetwork
    private let realmFactory: IRealmFactory
    private let hostDiscovery: IHostDiscovery
    private let dnsLookupQueue: DispatchQueue
    private let hostsUsageQueue: DispatchQueue
    private let localQueue: DispatchQueue
    private var collected: Bool = false
    private var usedHosts: [String] = []

    private let logger: Logger?

    weak var delegate: PeerHostManagerDelegate?

    init(network: INetwork, realmFactory: IRealmFactory, hostDiscovery: IHostDiscovery = HostDiscovery(),
         dnsLookupQueue: DispatchQueue = DispatchQueue(label: "PeerHostManager DNSLookupQueue", qos: .background, attributes: .concurrent),
         localQueue: DispatchQueue = DispatchQueue(label: "PeerHostManager LocalQueue", qos: .utility),
         hostsUsageQueue: DispatchQueue = DispatchQueue(label: "PeerHostManager HostsUsageQueue", qos: .utility), logger: Logger? = nil) {
        self.network = network
        self.realmFactory = realmFactory
        self.hostDiscovery = hostDiscovery
        self.dnsLookupQueue = dnsLookupQueue
        self.hostsUsageQueue = hostsUsageQueue
        self.localQueue = localQueue

        self.logger = logger
    }

    private func collectPeerHosts() {
        guard !collected else {
            return
        }

        collected = true
        for dnsSeed in self.network.dnsSeeds {
            dnsLookupQueue.async {
                self.addHosts(hosts: self.hostDiscovery.lookup(dnsSeed: dnsSeed))
            }
        }
    }

}

extension PeerHostManager: IPeerHostManager {

    var peerHost: String? {
        var host: String?
        
        hostsUsageQueue.sync {
            let realm = self.realmFactory.realm
            let peerAddress = realm.objects(PeerAddress.self).sorted(byKeyPath: "score").first(where: { !self.usedHosts.contains($0.ip) })

            if let peerAddress = peerAddress {
                self.usedHosts.append(peerAddress.ip)
            } else {
                self.collectPeerHosts()
            }

            host = peerAddress?.ip
        }
        
        return host
    }

    func hostDisconnected(host: String, withError error: Error?, networkReachable: Bool) {
        localQueue.sync {
            self.hostsUsageQueue.async {
                self.usedHosts.removeAll(where: { connectedHost in connectedHost == host })
            }

            let realm = self.realmFactory.realm
            if let peerAddress = realm.objects(PeerAddress.self).filter("ip = %@", host).first {
                do {
                    try realm.write {
                        if networkReachable && error != nil {
                            realm.delete(peerAddress)
                        } else {
                            peerAddress.score += 1
                        }
                    }
                } catch {
                    logger?.error("Could not process IP due to error: \(error)")
                }
            }
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
                self.logger?.debug("Adding new hosts: \(newPeerAddresses.count)")
                try realm.write {
                    realm.add(newPeerAddresses)
                }
            } catch {
                self.logger?.error("Could not add PeerAddresses due to error: \(error)")
            }

            self.delegate?.newHostsAdded()
        }
    }

}
