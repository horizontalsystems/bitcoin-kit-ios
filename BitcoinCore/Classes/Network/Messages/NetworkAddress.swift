import Foundation
import OpenSslKit

/// When a network address is needed somewhere,
/// this structure is used. Network addresses are not prefixed with a timestamp in the version message.
public struct NetworkAddress {
    let services: UInt64
    let address: String
    let port: UInt16

    init(services: UInt64, address: String, port: UInt16) {
        self.services = services
        self.address = address
        self.port = port
    }

    init(byteStream: ByteStream) {
        services = byteStream.read(UInt64.self)

        let addrData = byteStream.read(Data.self, count: 16)
        let addr = ipv6(from: addrData)
        if addr.hasPrefix("0000:0000:0000:0000:0000:ffff") {
            address = "0000:0000:0000:0000:0000:ffff:" + ipv4(from: addrData)
        } else {
            address = addr
        }


        port = byteStream.read(UInt16.self)
    }

    func serialized() -> Data {
        var data = Data()
        data += services.littleEndian
        data += pton(address)
        data += port.bigEndian
        return data
    }

    func supportsBloomFilter() -> Bool {
        ServiceFlags(rawValue: services).contains(ServiceFlags.bloom)
    }

}

extension NetworkAddress: CustomStringConvertible {
    public var description: String {
        return "[\(address)]:\(port.bigEndian) \(ServiceFlags(rawValue: services))"
    }
}
