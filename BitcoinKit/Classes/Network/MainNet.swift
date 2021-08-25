import BitcoinCore

class MainNet: INetwork {
    let bundleName = "BitcoinKit"

    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xf9beb4d9
    let port = 8333
    let coinType: UInt32 = 0
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "x5.seed.bitcoin.sipa.be",             // Pieter Wuille
        "x5.dnsseed.bluematt.me",              // Matt Corallo
        "x5.seed.bitcoinstats.com",            // Chris Decker
        "x5.seed.btc.petertodd.org",           // Peter Todd
        "x5.seed.bitcoin.sprovoost.nl",        // Sjors Provoost
        "x5.seed.bitnodes.io",                 // Addy Yeow
        "x5.dnsseed.emzy.de",                  // Stephan Oeste
        "x5.seed.bitcoin.wiz.biz"              // Jason Maurice
    ]

    let dustRelayTxFee = 3000 //  https://github.com/bitcoin/bitcoin/blob/master/src/policy/policy.h#L52
}
