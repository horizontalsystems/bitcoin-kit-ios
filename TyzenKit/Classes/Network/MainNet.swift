import BitcoinCore

public class MainNet: INetwork {
    public let bundleName = "TyzenKit"

    public let pubKeyHash: UInt8 = 0x42
    public let privateKey: UInt8 = 0xb0
    public let scriptHash: UInt8 = 0x80
    public let bech32PrefixPattern: String = "tzn"
    public let xPubKey: UInt32 = 0x03b47334
    public let xPrivKey: UInt32 = 0x03b473b9
    public let magic: UInt32 = 0xfbc0b6db
    public let port = 2332
    public let coinType: UInt32 = 2
    public let sigHash: SigHashType = .bitcoinAll
    public var syncableFromApi: Bool = true

    public let dnsSeeds = [
        "node1.tyzen.io",
        "node2.tyzen.io",
        "node3.tyzen.io",
        "node4.tyzen.io",
        "node5.tyzen.io",
        "node6.tyzen.io",
        "node7.tyzen.io",
        "node8.tyzen.io",
        "node9.tyzen.io",
        "node10.tyzen.io"
    ]

    public let dustRelayTxFee = 3000

    public init() {}

}
