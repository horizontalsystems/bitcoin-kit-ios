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

    let dustRelayTxFee = 1000 // https://github.com/dashpay/dash/blob/master/src/policy/policy.h#L36

    var bip44CheckpointBlock: Block {
        Block(
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
        Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "000000000000000087895fde87f60ba1eebf761a962f1a74ded6d5499b0b6660".reversedData!,
                        previousBlockHeaderHash: "0000000000000010751b0e9a8deb7d6589a339a3ffcb756d2d10f0cf203f5a1c".reversedData!,
                        merkleRoot: "ed933d1c7e48da67e96b2822edbb4c76fe8fe19b71241fc8bb51c6035fbf91d5".reversedData!,
                        timestamp: 1573116504,
                        bits: 420940927,
                        nonce: 1081860501
                ),
                height: 1166976)
    }

}
