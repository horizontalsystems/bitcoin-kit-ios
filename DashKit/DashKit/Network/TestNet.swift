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

    var bip44CheckpointBlock: Block {
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

    var lastCheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "000000000cf1ebc27139b55559f2a0e312e566e1fd7dcac7ccf4e58d973794f5".reversedData!,
                        previousBlockHeaderHash: "000000001099bd5d3c903f2ab865b2c49c8bd29bddc9c990db43acd99617362c".reversedData!,
                        merkleRoot: "e58aeda83f17834baedb488c5276a37376c61c375848761f9a02c1981fe0d507".reversedData!,
                        timestamp: 1559651035,
                        bits: 0x1c0f8fa9,
                        nonce: 1118140024
                ),
                height: 111324)
    }

}
