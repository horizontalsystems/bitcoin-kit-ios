import BitcoinCore

class RegTest: INetwork {
    let bundleName = "BitcoinKit"

    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "bcrt"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xfabfb5da
    let port = 18444
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
         "btc-regtest.horizontalsystems.xyz",
         "btc01-regtest.horizontalsystems.xyz",
         "btc02-regtest.horizontalsystems.xyz",
         "btc03-regtest.horizontalsystems.xyz",
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50
}
