import BitcoinCore

public class MainNet: INetwork {
    public let bundleName = "BitcoinKit"

    public let pubKeyHash: UInt8 = 0x00
    public let privateKey: UInt8 = 0x80
    public let scriptHash: UInt8 = 0x05
    public let bech32PrefixPattern: String = "bc"
    public let xPubKey: UInt32 = 0x0488b21e
    public let xPrivKey: UInt32 = 0x0488ade4
    public let magic: UInt32 = 0xf9beb4d9
    public let port = 8333
    public let coinType: UInt32 = 0
    public let sigHash: SigHashType = .bitcoinAll
    public var syncableFromApi: Bool = true

    public let dnsSeeds = [
        "x5.seed.bitcoin.sipa.be",             // Pieter Wuille
        "x5.dnsseed.bluematt.me",              // Matt Corallo
        "x5.seed.bitcoinstats.com",            // Chris Decker
        "x5.seed.btc.petertodd.org",           // Peter Todd
        "x5.seed.bitcoin.sprovoost.nl",        // Sjors Provoost
        "x5.seed.bitnodes.io",                 // Addy Yeow
        "x5.dnsseed.emzy.de",                  // Stephan Oeste
        "x5.seed.bitcoin.wiz.biz"              // Jason Maurice
    ]

    public let dustRelayTxFee = 3000 //  https://github.com/bitcoin/bitcoin/blob/master/src/policy/policy.h#L52

    public init() {}

}
