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
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048".reversedData!,
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
                        version: 805289984,
                        headerHash: "0000000000000000030e41502adfbcb20fdca66b15cc9e157449585c6c85da6e".reversedData!,
                        previousBlockHeaderHash: "000000000000000000e1f8ea917f17c378fdfd8d13f23160c6cb522d406c37ab".reversedData!,
                        merkleRoot: "923fb5f581b3dfe4bc6103891c63e5789abbaac7d8fcd2ba4b25ac2abccdba9c".reversedData!,
                        timestamp: 1557394860,
                        bits: 402883015,
                        nonce: 3963128149
                ),
                height: 581790)
    }

}
