import BitcoinCore

class TestNet: INetwork {
    let bundleName = "TyzenKit"

    let pubKeyHash: UInt8 = 0x42
    let privateKey: UInt8 = 0xb0
    let scriptHash: UInt8 = 0x80
    let bech32PrefixPattern: String = "ttzn"
    let xPubKey: UInt32 = 0x03ba2f80
    let xPrivKey: UInt32 = 0x03ba3005
    let magic: UInt32 = 0xfdd2c8f1
    let port = 20595
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
        "testnet1.tyzen.io",
        "testnet2.tyzen.io",
        "testnet3.tyzen.io",
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50
}
