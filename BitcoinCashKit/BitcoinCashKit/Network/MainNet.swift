import BitcoinCore

class MainNet: INetwork {

    let name = "bitcoin-cash-main-net"

    let maxBlockSize: UInt32 = 32 * 1024 * 1024
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let bech32PrefixPattern: String = "bitcoincash"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xe3e1f3e8
    let port: UInt32 = 8333
    let coinType: UInt32 = 0
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "seed.bitcoinabc.org",
        "seed-abc.bitcoinforks.org",
    ]

    var bip44CheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 2,
                        headerHash: "00000000000000003decdbb5f3811eab3148fbc29d3610528eb3b50d9ee5723f".reversedData!,
                        previousBlockHeaderHash: "00000000000000006bcf448b771c8f4db4e2ca653474e3b29504ec08422b3fba".reversedData!,
                        merkleRoot: "4ea18e999a57fc55fb390558dbb88a7b9c55c71c7de4cec160c045802ee587d2".reversedData!,
                        timestamp: 1397755646,
                        bits: 419470732,
                        nonce: 2160181286
                ),
                height: 296352)
    }

    var lastCheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "00000000000000000376c7174b3d07ca1797dbbda4247e0df02147a8748489e8".reversedData!,
                        previousBlockHeaderHash: "000000000000000000553bfbe09e381b8bf90aaf5918aec2a9ca04cbb380de4c".reversedData!,
                        merkleRoot: "eddba5abfaf472c82adfdb0585eb672fbcb142b4ca485d00e76afd9e71184991".reversedData!,
                        timestamp: 1566454348,
                        bits: 0x18039165,
                        nonce: 2279816485
                ),
                height: 596855)
    }

}
