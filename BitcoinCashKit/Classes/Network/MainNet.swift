import BitcoinCore

class MainNet: INetwork {
    let bundleName = "BitcoinCashKit"

    let maxBlockSize: UInt32 = 32 * 1024 * 1024
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let bech32PrefixPattern: String = "bitcoincash"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xe3e1f3e8
    let port = 8333
    let coinType: UInt32
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "x5.seed.bitcoinabc.org",                   // Bitcoin ABC seeder
        "btccash-seeder.bitcoinunlimited.info",     // BU backed seeder
        "x5.seeder.jasonbcox.com",                  // Jason B. Cox
        "seed.deadalnix.me",                        // Amaury SÉCHET
        "seed.bchd.cash",                           // BCHD
        "x5.seeder.fabien.cash"                     // Fabien
    ]

    let dustRelayTxFee = 3000

    init(coinType: CoinType = .type145) {
        self.coinType = coinType.rawValue
    }

}

public enum CoinType: UInt32 {
    case type0 = 0
    case type145 = 145
}
