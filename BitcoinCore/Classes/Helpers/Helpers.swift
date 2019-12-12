import Foundation

func ipv4(from data: Data) -> String {
    return Data(data.dropFirst(12)).map { String($0) }.joined(separator: ".")
}

func ipv6(from data: Data) -> String {
    return stride(from: 0, to: data.count - 1, by: 2).map { Data([data[$0], data[$0 + 1]]).hex }.joined(separator: ":")
}

func pton(_ address: String) -> Data {
    var addr = in6_addr()
    _ = withUnsafeMutablePointer(to: &addr) {
        inet_pton(AF_INET6, address, UnsafeMutablePointer($0))
    }
    var buffer = Data(count: 16)
    _ = buffer.withUnsafeMutableBytes { memcpy($0.baseAddress!.assumingMemoryBound(to: UInt8.self), &addr, 16) }
    return buffer
}

func byteArrayLittleEndian(int: Int) -> [UInt8] {
    return [
        UInt8(int & 0x000000FF),
        UInt8((int & 0x0000FF00) >> 8),
        UInt8((int & 0x00FF0000) >> 16),
        UInt8((int & 0xFF000000) >> 24)
    ]
}
