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
                        version: 536870928,
                        headerHash: "00000000000000011ce58a8bb55333277640b015e97689f9277d582a4c1f9999".reversedData!,
                        previousBlockHeaderHash: "000000000000000fcbac491b68a0774d1b9f82edeae8742eb492815e8fa76ca5".reversedData!,
                        merkleRoot: "91e15e6045c20d06abc41eb5feb17813ccc723f6f018ca8fd01485e8837bc761".reversedData!,
                        timestamp: 1559624664,
                        bits: 0x191a414a,
                        nonce: 838341360
                ),
                height: 1081358)
    }

}
