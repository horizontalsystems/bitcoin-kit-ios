import BitcoinCore

class TestNet: INetwork {
    let protocolVersion: Int32 = 70214

    let name = "dash-main-net"

    let maxBlockSize: UInt32 = 1_000_000_000
    let pubKeyHash: UInt8 = 0x8c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x13
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xcee2caff
    let port: UInt32 = 19999
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.dashdot.io",
        "test.dnsseed.masternode.io"
    ]

    var genesisBlock: Block {
        return Block(
            withHeader: BlockHeader(
                    version: 1,
                    headerHash: "00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c".reversedData!,
                    previousBlockHeaderHash: "0000000000000000000000000000000000000000000000000000000000000000".reversedData!,
                    merkleRoot: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".reversedData!,
                    timestamp: 1231006505,
                    bits: 486604799,
                    nonce: 2083236893
            ),
            height: 0)
    }

    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "00000000064ca5bc01e45950d863fb7e938bdb9ecdec698e8d7acfb79a57d15e".reversedData!,
                        previousBlockHeaderHash: "0000000006616ee85366fabce00a28af650519eb1c6106d613ce3678947a42fb".reversedData!,
                        merkleRoot: "fe39bdb86999ba1eaca10e56bf12528c9cce278c8dde66f399605d8e79e12fe6".reversedData!,
                        timestamp: 1554724358,
                        bits: 0x1c09e0a2,
                        nonce: 3017212751
                ),
                height: 75900)
    }

}
