import BitcoinCore

class RegTest: INetwork {

    let name = "bitcoin-reg-test"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "bcrt"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xfabfb5da
    let port: UInt32 = 18444
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
         "btc-regtest.horizontalsystems.xyz",
         "btc01-regtest.horizontalsystems.xyz",
         "btc02-regtest.horizontalsystems.xyz",
         "btc03-regtest.horizontalsystems.xyz",
    ]

    var bip44CheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: Data(repeating: 0, count: 32),
                        previousBlockHeaderHash: Data(repeating: 0, count: 32),
                        merkleRoot: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".reversedData!,
                        timestamp: 1296688602,
                        bits: 545259519,
                        nonce: 2
                ),
                height: 0)
    }

    var lastCheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: Data(repeating: 0, count: 32),
                        previousBlockHeaderHash: Data(repeating: 0, count: 32),
                        merkleRoot: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".reversedData!,
                        timestamp: 1296688602,
                        bits: 545259519,
                        nonce: 2
                ),
                height: 0)
    }

}
