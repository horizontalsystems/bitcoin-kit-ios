import BitcoinCore

class TestNet: INetwork {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    let name = "bitcoin-test-net"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let bech32PrefixPattern: String = "tb"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0x0b110907
    let port: UInt32 = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.bitcoin.petertodd.org",    // Peter Todd
        "testnet-seed.bitcoin.jonasschnelli.ch", // Jonas Schnelli
        "testnet-seed.bluematt.me",              // Matt Corallo
        "testnet-seed.bitcoin.schildbach.de",    // Andreas Schildbach
        "bitcoin-testnet.bloqseeds.net",         // Bloq
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50

    var bip44CheckpointBlock: Block {
        Block(
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
        Block(
                withHeader: BlockHeader(
                        version: 0x20000000,
                        headerHash: "0000000000009038ad7a5d86e7f6c825a4665a46b23fd7827e889535e51eecb4".reversedData!,
                        previousBlockHeaderHash: "0000000000019a6ef183423833a4347d77e8687b4fc83a85f4c98c579631acbe".reversedData!,
                        merkleRoot: "b53da26be2fc522b64d948aa8c32e89ac8b426624c658446b164d54c1f23c685".reversedData!,
                        timestamp: 1576743613,
                        bits: 0x1b00ffff,
                        nonce: 0x42a6e7cf
                ),
                height: 1628928)
    }

}
