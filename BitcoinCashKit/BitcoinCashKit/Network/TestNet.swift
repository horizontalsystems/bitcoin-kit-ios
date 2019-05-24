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
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943".reversedData!,
                        previousBlockHeaderHash: "0000000000000000000000000000000000000000000000000000000000000000".reversedData!,
                        merkleRoot: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".reversedData!,
                        timestamp: 1296688602,
                        bits: 486604799,
                        nonce: 414098458
                ),
                height: 0)
    }

    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "000000002d867bde415b82a4a276e802d1536c632d9138d599dba930cf45e2c3".reversedData!,
                        previousBlockHeaderHash: "000000000dea8d3a526bc2d7b3a26588935992a1a412a6c5c449ffaa41b070b0".reversedData!,
                        merkleRoot: "dfa42c8fc3d8bac6d6fb51007128092f41d590ace1b3522af7062b8a848ebde7".reversedData!,
                        timestamp: 1551085591,
                        bits: 486604799,
                        nonce: 1684221831
                ),
                height: 1287761)
    }

}
