import Foundation
import UIExtensions

class PeerDiscovery: IPeerDiscovery {
    weak var peerAddressManager: IPeerAddressManager?

    func lookup(dnsSeed: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let ips = self?._lookup(dnsSeed: dnsSeed) {
                self?.peerAddressManager?.add(ips: ips)
            }
        }
    }

    private func _lookup(dnsSeed: String) -> [String] {
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
