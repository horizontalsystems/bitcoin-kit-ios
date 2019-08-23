import BitcoinCore

class MainNet: INetwork {

    let protocolVersion: Int32 = 70214

    let name = "dash-main-net"

    let maxBlockSize: UInt32 = 2_000_000_000
    let pubKeyHash: UInt8 = 0x4c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x10
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xbf0c6bbd
    let port: UInt32 = 9999
    let coinType: UInt32 = 5
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "dnsseed.dash.org",
        "dnsseed.dashdot.io",
        "dnsseed.masternode.io",
    ]

    var bip44CheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "00000ffd590b1485b3caadc19b22e6379c733355108f107a430458cdf3407ab6".reversedData!,
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
                        headerHash: "0000000000000007025cba534229ad1aea320e71396c81a567ee73d1d4d08dbd".reversedData!,
                        previousBlockHeaderHash: "000000000000000a80683bb332ddb2d29d2404addd6b84ba4ec574d3347726c6".reversedData!,
                        merkleRoot: "f9f9916a421d732ac78661fad94f8b605c57cd6653f533fd2460912950147e6b".reversedData!,
                        timestamp: 1566523466,
                        bits: 421091794,
                        nonce: 565120927
                ),
                height: 1125153)
    }

}
