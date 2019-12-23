import Foundation

class PeerAddressManagerState {
    private let queue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.peer-address-manager-state", qos: .utility)
    private(set) var usedIps: [String] = []

    func add(usedIp: String) {
        queue.sync {
            self.usedIps.append(usedIp)
        }
    }

    func remove(usedIp: String) {
        queue.sync {
            self.usedIps.removeAll(where: { $0 == usedIp })
        }
    }
}
