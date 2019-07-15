import BitcoinCore

class TestNet: INetwork {

    let name = "bitcoin-cash-test-net"

    let maxBlockSize: UInt32 = 32 * 1024 * 1024
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "bchtest"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xf4e5f3f4
    let port: UInt32 = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.bitcoinabc.org",
    ]

    var bip44CheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 2,
                        headerHash: "000000000000bbde3a83bd29bc5cacd73f039f345318e7a4088914342c9d259a".reversedData!,
                        previousBlockHeaderHash: "0000000003dc49f7472f960eedb4fb2d1ccc8b0530ca6c75ed2bba9718b6f297".reversedData!,
                        merkleRoot: "a60fdbc889976c573450e9f78f1c330e374968a54f294e427180da1e9a07806b".reversedData!,
                        timestamp: 1393645018,
                        bits: 0x1c0180ab,
                        nonce: 634051227
                ),
                height: 199584)
    }

    var lastCheckpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 0x20000000,
                        headerHash: "00000000000001c4a2ebbed0841005d527c5177f323cd3df5d9f70463d9c28c7".reversedData!,
                        previousBlockHeaderHash: "000000000000046bf1879dc49620b0b12d4faaeda6f0ee033fc2cb86382ce571".reversedData!,
                        merkleRoot: "a9e1f20ec48ce7fae824c0dd76b4c4ec354d623e0ad2fac7b66a06984c0c0f81".reversedData!,
                        timestamp: 1562665562,
                        bits: 0x1a0509d6,
                        nonce: 437871866
                ),
                height: 1313735)
    }

}
