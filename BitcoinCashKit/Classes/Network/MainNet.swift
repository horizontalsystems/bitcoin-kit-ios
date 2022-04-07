import BitcoinCore

public class MainNet: INetwork {
    public let bundleName = "BitcoinCashKit"

    public let maxBlockSize: UInt32 = 32 * 1024 * 1024
    public let pubKeyHash: UInt8 = 0x00
    public let privateKey: UInt8 = 0x80
    public let scriptHash: UInt8 = 0x05
    public let bech32PrefixPattern: String = "bitcoincash"
    public let xPubKey: UInt32 = 0x0488b21e
    public let xPrivKey: UInt32 = 0x0488ade4
    public let magic: UInt32 = 0xe3e1f3e8
    public let port = 8333
    public let coinType: UInt32
    public let sigHash: SigHashType = .bitcoinCashAll
    public var syncableFromApi: Bool = true

    public let dnsSeeds = [
        "x5.seed.bitcoinabc.org",                   // Bitcoin ABC seeder
        "btccash-seeder.bitcoinunlimited.info",     // BU backed seeder
        "x5.seeder.jasonbcox.com",                  // Jason B. Cox
        "seed.deadalnix.me",                        // Amaury SÉCHET
        "seed.bchd.cash",                           // BCHD
        "x5.seeder.fabien.cash"                     // Fabien
    ]

    public let dustRelayTxFee = 3000

    public init(coinType: CoinType = .type145) {
        self.coinType = coinType.rawValue
    }

}

public enum CoinType: UInt32 {
    case type0 = 0
    case type145 = 145
}
