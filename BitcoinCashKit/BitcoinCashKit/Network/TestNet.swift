import BitcoinCore

class TestNet: INetwork {

    let name = "bitcoin-cash-test-net"

    let maxBlockSize: UInt32 = 32 * 1024 * 1024
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "bchtest"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xf4e5f3f4
    let port: UInt32 = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.bitcoinabc.org",
        "testnet-seed-abc.bitcoinforks.org"
    ]

    let dustRelayTxFee = 1000    // https://github.com/Bitcoin-ABC/bitcoin-abc/blob/master/src/policy/policy.h#L78

    var bip44CheckpointBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 2,
                        headerHash: "000000000000bbde3a83bd29bc5cacd73f039f345318e7a4088914342c9d259a".reversedData!,
                        previousBlockHeaderHash: "0000000003dc49f7472f960eedb4fb2d1ccc8b0530ca6c75ed2bba9718b6f297".reversedData!,
                        merkleRoot: "a60fdbc889976c573450e9f78f1c330e374968a54f294e427180da1e9a07806b".reversedData!,
                        timestamp: 1393645018,
                        bits: 0x1c0180ab,
                        nonce: 634051227
                ),
                height: 199584)
    }

    var lastCheckpointBlock: Block {
        Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "0000000017dbffd594e34e02b1033a37da40056a0cf8f4fd3bb8f373336ebc4e".reversedData!,
                        previousBlockHeaderHash: "00000000000942fa7c29649a86241e4311a84536861c42cf617fda2682fe855e".reversedData!,
                        merkleRoot: "bb8410c2a763ea3aa4cb6d2679b8a6a2887afe377f5ba28f1af5a3d52bba7e83".reversedData!,
                        timestamp: 1573097953,
                        bits: 486604799,
                        nonce: 3758956418
                        ),
                height: 1339023)
    }

}
