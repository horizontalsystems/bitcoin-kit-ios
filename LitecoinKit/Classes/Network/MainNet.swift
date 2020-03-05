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
    let port: UInt32 = 9333
    let coinType: UInt32 = 2
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
        "dnsseed.litecoinpool.org",
        "seed-a.litecoin.loshan.co.uk",
        "dnsseed.thrasher.io",
        "dnsseed.koin-project.com",
        "dnsseed.litecointools.com",
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50
}
