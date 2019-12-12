import BitcoinCore

class MainNet: INetwork {

    let name = "bitcoin-main-net"
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xf9beb4d9
    let port: UInt32 = 8333
    let coinType: UInt32 = 0
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "seed.bitcoin.sipa.be",         // Pieter Wuille
        "dnsseed.bluematt.me",          // Matt Corallo
        "dnsseed.bitcoin.dashjr.org",   // Luke Dashjr
        "seed.bitcoinstats.com",        // Chris Decker
        "seed.bitnodes.io",             // Addy Yeow
        "seed.bitcoin.jonasschnelli.ch",// Jonas Schnelli
    ]

    let dustRelayTxFee = 3000 // https://github.com/bitcoin/bitcoin/blob/c536dfbcb00fb15963bf5d507b7017c241718bf6/src/policy/policy.h#L50

    var bip44CheckpointBlock: Block {
        Block(
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
        Block(
                withHeader: BlockHeader(
                        version: 536879104,
                        headerHash: "0000000000000000000983a15a2735b4f37861c4019d97200820cd190f28dba5".reversedData!,
                        previousBlockHeaderHash: "0000000000000000000676463abf3771ea01e0f8c948d1c93658a1d82d95df5a".reversedData!,
                        merkleRoot: "24415cca3979b6f1b6a19c63160bf732030b1031b5615d98efe8c2cee083175e".reversedData!,
                        timestamp: 1571866973,
                        bits: 387223263,
                        nonce: 1093878582
                ),
                height: 600768)
    }

}
