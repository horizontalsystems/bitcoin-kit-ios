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

    var bip44CheckpointBlock: Block {
        return Block(
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
        return Block(
                withHeader: BlockHeader(
                        version: 541065216,
                        headerHash: "000000000000036ab860e5f4fabd32910018cba8dcac7388a9fe39696a8c44e7".reversedData!,
                        previousBlockHeaderHash: "000000000000030f449112975b4b6e354d97a5c518289a59f6b56549ff3368bd".reversedData!,
                        merkleRoot: "ad38ccce41340b04a0f56dbb8336a79bf7bcc081e6f2fc0547e70944e5f6cda5".reversedData!,
                        timestamp: 1566231970,
                        bits: 0x1a050d88,
                        nonce: 2919755716
                ),
                height: 1322849)
    }

}
