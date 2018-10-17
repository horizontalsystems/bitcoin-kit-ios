import Foundation

/// Provide information on known nodes of the network. Non-advertised nodes should be forgotten after typically 3 hours
struct AddressMessage: IMessage {
    /// Number of address entries (max: 1000)
    let count: VarInt
    /// Address of other nodes on the network. version < 209 will only read the first one.
    /// The uint32_t is a timestamp (see note below).
    let addressList: [NetworkAddress]

    init(data: Data) {
        let byteStream = ByteStream(data)

        count = byteStream.read(VarInt.self)

        var addressList = [NetworkAddress]()
        for _ in 0..<count.underlyingValue {
            _ = byteStream.read(UInt32.self) // Timestamp
            addressList.append(NetworkAddress(byteStream: byteStream))
        }

        self.addressList = addressList
    }

    func serialized() -> Data {
        return Data()
    }

}
