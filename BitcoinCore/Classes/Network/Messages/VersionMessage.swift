/// When a node creates an outgoing connection, it will immediately advertise its version.
/// The remote node will respond with its version. No further communication is possible until both peers have exchanged their version.
struct VersionMessage: IMessage {
    /// Identifies protocol version being used by the node
    let version: Int32
    /// bitfield of features to be enabled for this connection
    let services: UInt64
    /// standard UNIX timestamp in seconds
    let timestamp: Int64
    // The network address of the node receiving this message
    let yourAddress: NetworkAddress
    /* Fields below require version ≥ 106 */
    /// The network address of the node emitting this message
    let myAddress: NetworkAddress?
    /// Node random nonce, randomly generated every time a version packet is sent. This nonce is used to detect connections to self.
    let nonce: UInt64?
    /// User Agent (0x00 if string is 0 bytes long)
    let userAgent: VarString?
    // The last block received by the emitting node
    let startHeight: Int32?
    /* Fields below require version ≥ 70001 */
    /// Whether the remote peer should announce relayed transactions or not, see BIP 0037
    let relay: Bool?

    func hasBlockChain(network: INetwork) -> Bool {
        (services & network.serviceFullNode) == network.serviceFullNode
    }

    func supportsBloomFilter(network: INetwork) -> Bool {
        (version > 70000 && version < 70011) || (version > 70000 && ServiceFlags(rawValue: services).contains(ServiceFlags.bloom))
    }

    var description: String {
        "\(version) --- \(userAgent?.value ?? "") --- \(ServiceFlags(rawValue: services)) -- \(String(describing: startHeight ?? 0))"
    }

}
