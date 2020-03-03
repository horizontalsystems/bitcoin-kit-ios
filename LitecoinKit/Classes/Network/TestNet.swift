import BitcoinCore

class TestNet: INetwork {
    let name = "litecoin-test-net"
    let bundleName = "LitecoinKit"

    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0x3a
    let bech32PrefixPattern: String = "tltc"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xfdd2c8f1
    let port: UInt32 = 19335
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
        "testnet-seed.ltc.xurious.com",
        "seed-b.litecoin.loshan.co.uk",
        "dnsseed-testnet.thrasher.io",
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50

    var bip44CheckpointBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "dc19bf491bf601e2a05fd37372f6dc1a51feba5f0f35cf944d39334e79790f5b".reversedData!,
                        previousBlockHeaderHash: "4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0".reversedData!,
                        merkleRoot: "f7a718f20ea4529351892e70a563f1c58af5e720798e475cc677302ebef92513".reversedData!,
                        timestamp: 1486961886,
                        bits: 0x1e0fffff,
                        nonce: 4136305408
                ),
                height: 1)
    }

    var lastCheckpointBlock: Block {
        bip44CheckpointBlock
    }

}
