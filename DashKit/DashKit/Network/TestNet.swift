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

    let dustRelayTxFee = 1000 // https://github.com/dashpay/dash/blob/master/src/policy/policy.h#L36

    var bip44CheckpointBlock: Block {
        Block(
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
        Block(
                withHeader: BlockHeader(
                        version: 536870912,
                        headerHash: "000008fd74af527d0278b11ebdfed0e729e5cb97009e0cf1d60ae2559bf19b5a".reversedData!,
                        previousBlockHeaderHash: "000007bec14c122412335571908232996015c0eb49cb475796fac40154853b8f".reversedData!,
                        merkleRoot: "c018ec01fe4187701059d959e443cb7b653672106d727cd1a2e73bc1dc9ef69b".reversedData!,
                        timestamp: 1573118434,
                        bits: 504216786,
                        nonce: 8013
                ),
                height: 206472)
    }

}
