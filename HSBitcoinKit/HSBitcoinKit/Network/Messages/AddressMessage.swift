import Foundation

/// Provide information on known nodes of the network. Non-advertised nodes should be forgotten after typically 3 hours
struct AddressMessage: IMessage {
    let command = "inv"
    /// Number of address entries (max: 1000)
    let count: VarInt
    /// Address of other nodes on the network. version < 209 will only read the first one.
    /// The uint32_t is a timestamp (see note below).
    let addressList: [NetworkAddress]

    init(addresses: [NetworkAddress]) {
        count = VarInt(addresses.count)
        addressList = addresses
    }

}
