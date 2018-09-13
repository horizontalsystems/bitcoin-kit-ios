import Foundation
import RealmSwift

class PeerIpManager {
    let network: NetworkProtocol
    let realmFactory: RealmFactory
    let q: DispatchQueue
    var collecting: Bool = false
    weak var delegate: PeerIpManagerDelegate?

    var peerHost: String? {
        let realm = realmFactory.realm
        guard let peerAddress = realm.objects(PeerAddress.self).filter("using = %@", false).sorted(byKeyPath: "score").first else {
            return nil
        }

        do {
            try realm.write {
                peerAddress.using = true
            }
            return peerAddress.ip
        } catch {
            return nil
        }
    }

    init(network: NetworkProtocol, realmFactory: RealmFactory) {
        self.network = network
        self.realmFactory = realmFactory
        q = DispatchQueue(label: "PeerIpManager Queue", qos: .background)
    }

    func collectPeerHosts() {
        guard !collecting else {
            return
        }
        collecting = true

        guard let delegate = self.delegate else {
            return
        }

        let peerAddressesCount = resetExistingAddresses()
        guard peerAddressesCount < delegate.peerCount else {
            delegate.ipManagerReady()
            return
        }

        q.async {
            let realm = self.realmFactory.realm
            let peerAddresses = realm.objects(PeerAddress.self)
            var newIps = [String]()

            for dnsSeed in self.network.dnsSeeds {
                newIps.append(contentsOf: self.lookup(dnsSeed: dnsSeed))
            }

            let newPeerAddresses = newIps
                    .filter({ ip in !peerAddresses.contains(where: { peerAddress in peerAddress.ip == ip }) })
                    .map({ ip in PeerAddress(ip: ip, score: 0, using: false) })

            do {
                try realm.write {
                    realm.add(newPeerAddresses)
                }
            } catch {
                Logger.shared.log(self, "could not add PeerAddresses due to error: \(error)")
            }

            if peerAddresses.count < delegate.peerCount {
                delegate.peerCount = peerAddresses.count
                Logger.shared.log(self, "Not enough IP's found while DNS lookup. Decreasing peerCount to \(delegate.peerCount)")
            }

            delegate.ipManagerReady()
            self.collecting = false
        }
    }

    func markSuccess(ip: String) {
        let realm = realmFactory.realm
        if let peerAddress = realm.objects(PeerAddress.self).filter("ip = %@", ip).first {
            do {
                try realm.write {
                    peerAddress.using = false
                    peerAddress.score += 1
                }
            } catch {
                Logger.shared.log(self, "could not release using IP due to error: \(error)")
            }
        }
    }

    func markFailed(ip: String) {
        let realm = realmFactory.realm
        if let peerAddress = realm.objects(PeerAddress.self).filter("ip = %@", ip).first {
            do {
                try realm.write {
                    realm.delete(peerAddress)
                }
            } catch {
                Logger.shared.log(self, "could not remove IP due to error: \(error)")
            }
        }
    }

    private func resetExistingAddresses() -> Int {
        let realm = realmFactory.realm
        let peerAddresses = realm.objects(PeerAddress.self)
        try? realm.write {
            for peerAddress in peerAddresses {
                peerAddress.using = false
            }
        }

        return peerAddresses.count
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
    func ipManagerReady()
}
