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
                        headerHash: "000000000d5cbf42cd0da22e4a2dc4aab275a5e8d5a8ab39025b1bd2d588ebfb".reversedData!,
                        previousBlockHeaderHash: "000000000e34afe7600a439c89dbbb90908a6bf2bc117dcf30e82c89a83ec280".reversedData!,
                        merkleRoot: "334130f690b9e58bfc61c767c89251913e87dd7a44a1eb30bdd0668d85313527".reversedData!,
                        timestamp: 1566527727,
                        bits: 0x1c0f2298,
                        nonce: 958408694
                ),
                height: 160834)
    }

}
