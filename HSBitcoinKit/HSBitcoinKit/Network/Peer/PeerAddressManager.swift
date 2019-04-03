class PeerAddressManager {
    weak var delegate: IPeerAddressManagerDelegate?

    private let storage: IStorage
    private let dnsSeeds: [String]
    private var peerDiscovery: IPeerDiscovery
    private let state: PeerAddressManagerState
    private let logger: Logger?

    init(storage: IStorage, dnsSeeds: [String], peerDiscovery: IPeerDiscovery, state: PeerAddressManagerState = PeerAddressManagerState(), logger: Logger? = nil) {
        self.storage = storage
        self.dnsSeeds = dnsSeeds
        self.peerDiscovery = peerDiscovery
        self.state = state
        self.logger = logger
    }

}

extension PeerAddressManager: IPeerAddressManager {

    var ip: String? {
        guard let ip = storage.leastScorePeerAddress(excludingIps: state.usedIps)?.ip else {
            for dnsSeed in dnsSeeds {
                peerDiscovery.lookup(dnsSeed: dnsSeed)
            }

            return nil
        }

        state.add(usedIp: ip)

        return ip
    }

    func markSuccess(ip: String) {
        state.remove(usedIp: ip)
        storage.increasePeerAddressScore(ip: ip)
    }


    func markFailed(ip: String) {
        state.remove(usedIp: ip)
        storage.deletePeerAddress(byIp: ip)
    }

    func add(ips: [String]) {
        guard !ips.isEmpty else {
            return
        }

        let existingAddresses = storage.existingPeerAddresses(fromIps: ips)

        let newAddresses = ips
                .filter { ip in !existingAddresses.contains(where: { $0.ip == ip }) }
                .unique
                .map { PeerAddress(ip: $0, score: 0) }

        logger?.debug("Adding new addresses: \(newAddresses.count)")

        storage.save(peerAddresses: newAddresses)

        delegate?.newIpsAdded()
    }

}
