import BitcoinCore

public class MainNet: INetwork {
    public let protocolVersion: Int32 = 70220

    public let bundleName = "DashKit"

    public let maxBlockSize: UInt32 = 2_000_000_000
    public let pubKeyHash: UInt8 = 0x4c
    public let privateKey: UInt8 = 0x80
    public let scriptHash: UInt8 = 0x10
    public let bech32PrefixPattern: String = "bc"
    public let xPubKey: UInt32 = 0x0488b21e
    public let xPrivKey: UInt32 = 0x0488ade4
    public let magic: UInt32 = 0xbf0c6bbd
    public let port = 9999
    public let coinType: UInt32 = 5
    public let sigHash: SigHashType = .bitcoinAll
    public var syncableFromApi: Bool = true

    public let dnsSeeds = [
        "dnsseed.dash.org",
        "x5.dnsseed.dashdot.io",
        "dnsseed.masternode.io",
    ]

    public let dustRelayTxFee = 3000 // https://github.com/dashpay/dash/blob/master/src/policy/policy.h#L38

    public init() {}
}
