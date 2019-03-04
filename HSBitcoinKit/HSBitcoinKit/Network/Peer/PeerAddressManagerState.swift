import Foundation

class PeerAddressManagerState {
    private let queue = DispatchQueue(label: "PeerAddressManager.State", qos: .utility)
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
