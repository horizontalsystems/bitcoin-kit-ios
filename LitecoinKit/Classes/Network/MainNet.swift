import BitcoinCore

class MainNet: INetwork {
    let name = "litecoin-main-net"
    let bundleName = "LitecoinKit"

    let pubKeyHash: UInt8 = 0x30
    let privateKey: UInt8 = 0xb0
    let scriptHash: UInt8 = 0x32
    let bech32PrefixPattern: String = "ltc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xfbc0b6db
    let port: UInt32 = 9333
    let coinType: UInt32 = 2
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
        "dnsseed.litecoinpool.org",
        "seed-a.litecoin.loshan.co.uk",
        "dnsseed.thrasher.io",
        "dnsseed.koin-project.com",
        "dnsseed.litecointools.com",
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50

    var bip44CheckpointBlock: Block {
//        Block(
//                withHeader: BlockHeader(
//                        version: 536870912,
//                        headerHash: "77882e9351f9094c1500a8c904a3a545cc04412722c48482c72e58e11c76ed61".reversedData!,
//                        previousBlockHeaderHash: "c34fc9aba88593f45def605fd28602853a76a6848287db27cb70c0dae2b817eb".reversedData!,
//                        merkleRoot: "6e788b598a68c22768c685546128f943ebb90dcfca30b13c99cd97e78b03d630".reversedData!,
//                        timestamp: 1582454390,
//                        bits: 0x1a02ceb9,
//                        nonce: 4019904208
//                ),
//                height: 1794240)
        Block(
                withHeader: BlockHeader(
                        version: 2,
                        headerHash: "256a05e5154fad3e86b1bd0066ba7314a28ed83ff7b7bbb6dec6a5e3262a749f".reversedData!,
                        previousBlockHeaderHash: "636a10f30811889ed382cefd3643903e0cb432b3c52e47f328a8f19bc89b2f98".reversedData!,
                        merkleRoot: "9986047ecd48b4c149b22500f059640d07ed3b27af112be4acf38e376343ec9f".reversedData!,
                        timestamp: 1398284155,
                        bits: 0x1b0c7a03,
                        nonce: 3717250361
                ),
                height: 554400)
    }

    var lastCheckpointBlock: Block {
        bip44CheckpointBlock
    }

}
