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
                        version: 1073676288,
                        headerHash: "000000000000013d3dd95fb84b56616dd29409dc9750e200b2c19f435e561d5e".reversedData!,
                        previousBlockHeaderHash: "00000000000002845d416fbfa05a5d40ba5ba5418a64f06443042a53cf1fd608".reversedData!,
                        merkleRoot: "5cf68623e65eed4af3d669fd3680bbc5f7781a9ff9f8bd8d44e40ad06416fba4".reversedData!,
                        timestamp: 1556877853,
                        bits: 436373240,
                        nonce: 388744679
                ),
                height: 1514016)
    }

}
