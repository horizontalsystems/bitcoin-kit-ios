import BitcoinCore
import HSCryptoX11

class MainNet: INetwork {

    let protocolVersion: Int32 = 70213

    let name = "dash-main-net"

    let maxBlockSize: UInt32 = 2_000_000_000
    let pubKeyHash: UInt8 = 0x4c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x10
    let pubKeyPrefixPattern: String = "X"
    let scriptPrefixPattern: String = "7"
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

    var genesisBlock: Block {
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
    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "000000000000000608ce4cc5480ab345bf42f125521f0f7833125f09c9fd0688".reversedData!,
                        previousBlockHeaderHash: "0000000000000006d96ef1ae146bed5f1c769f3966a65df5f4ede44f375ae6fb".reversedData!,
                        merkleRoot: "5a764cf4380b768a8e4a015329b27d837278e499d1ff25efbe7f2ce02f6fcdc6".reversedData!,
                        timestamp: 1555924446,
                        bits: 421670238,
                        nonce: 903050513
                ),
                height: 1058000)
    }

}
