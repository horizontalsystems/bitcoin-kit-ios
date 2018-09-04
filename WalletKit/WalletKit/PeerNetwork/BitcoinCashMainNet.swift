import Foundation

class BitcoinCashMainNet: NetworkProtocol {
    let name = "bitcoin-cash-main-net"
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let pubKeyPrefixPattern: String = "q"
    let scriptPrefixPattern: String = "p"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xe3e1f3e8
    let port: UInt32 = 8333
    let coinType: UInt32 = 0

    let dnsSeeds = [
        "seed.bitcoinabc.org",
    ]

    let genesisBlock = Block(
            withHeader: BlockHeader(
                    version: 1,
                    previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                    merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                    timestamp: 1231006505,
                    bits: 486604799,
                    nonce: 2083236893
            ),
            height: 0)

    let checkpointBlock = Block(
            withHeader: BlockHeader(
                    version: 536870912,
                    previousBlockHeaderReversedHex: "000000000000000000c27f91198eb5505005a0863d8deb696a27e2f5bfffe70b",
                    merkleRootReversedHex: "1530edf433fdfd7252bda07bf38629e2c31f31560dbd30dd7f496c4b6fe7e27d",
                    timestamp: 1534820198,
                    bits: 402796414,
                    nonce: 1748283264
            ),
            height: 544320)

}
