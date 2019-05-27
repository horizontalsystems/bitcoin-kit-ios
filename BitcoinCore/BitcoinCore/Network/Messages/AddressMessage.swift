/// Provide information on known nodes of the network. Non-advertised nodes should be forgotten after typically 3 hours
struct AddressMessage: IMessage {
    /// Address of other nodes on the network. version < 209 will only read the first one.
    /// The uint32_t is a timestamp (see note below).
    let addressList: [NetworkAddress]

    init(addresses: [NetworkAddress]) {
        addressList = addresses
    }

    var description: String {
        return "\(addressList.count) address(es)"
    }

}
