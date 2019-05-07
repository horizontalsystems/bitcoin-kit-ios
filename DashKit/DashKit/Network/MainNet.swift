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
                        headerHash: "0000000000000008368fb8430955ff8c14080e170bff1856877a037d7de9ca0f".reversedData!,
                        previousBlockHeaderHash: "000000000000001f7388f389c62aecab926fa6cc36cb4f308e95c7635aae60db".reversedData!,
                        merkleRoot: "5a764cf4380b768a8e4a015329b27d837278e499d1ff25efbe7f2ce02f6fcdc6".reversedData!,
                        timestamp: 1557189938,
                        bits: 0x19204fc0,
                        nonce: 2178073180
                ),
                height: 1065900)
    }

}
