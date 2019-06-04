import BitcoinCore

class TestNet: INetwork {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    let name = "bitcoin-test-net"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "tb"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0x0b110907
    let port: UInt32 = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.bitcoin.petertodd.org",    // Peter Todd
        "testnet-seed.bitcoin.jonasschnelli.ch", // Jonas Schnelli
        "testnet-seed.bluematt.me",              // Matt Corallo
        "testnet-seed.bitcoin.schildbach.de",    // Andreas Schildbach
        "bitcoin-testnet.bloqseeds.net",         // Bloq
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
                        version: 0x20000000,
                        headerHash: "000000000000011b820755b3bbe03de7f7b8854b9f03307f41dafea4694eee7b".reversedData!,
                        previousBlockHeaderHash: "00000000000001d6874b4d88e387098c0b7100ff674d99781fc7045a78216a15".reversedData!,
                        merkleRoot: "d108b1c6229e1bc0c5506307779c6a51b1cb4c8edf3f91bef36dd1a2c30dfc99".reversedData!,
                        timestamp: 1558613325,
                        bits: 436289093,
                        nonce: 2472615319
                ),
                height: 1518048)
    }

}
