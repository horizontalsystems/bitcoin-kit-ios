import BitcoinCore

class MainNet: INetwork {
    let bundleName = "LitecoinKit"

    let pubKeyHash: UInt8 = 0x30
    let privateKey: UInt8 = 0xb0
    let scriptHash: UInt8 = 0x32
    let bech32PrefixPattern: String = "ltc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xfbc0b6db
    let port = 9333
    let coinType: UInt32 = 2
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "x5.dnsseed.thrasher.io",
        "x5.dnsseed.litecointools.com",
        "x5.dnsseed.litecoinpool.org",
        "seed-a.litecoin.loshan.co.uk"
    ]

    let dustRelayTxFee = 3000
}
