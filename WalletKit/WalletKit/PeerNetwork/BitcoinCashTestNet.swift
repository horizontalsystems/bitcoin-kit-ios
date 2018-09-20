import Foundation

class BitcoinCashTestNet: NetworkProtocol {
    private let headerValidator: IBlockValidator

    let name = "bitcoin-cash-test-net"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let pubKeyPrefixPattern: String = "q"
    let scriptPrefixPattern: String = "p"
    let bech32PrefixPattern: String = "bitcoincash"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xf4e5f3f4
    let port: UInt32 = 18333
    let coinType: UInt32 = 1

    let dnsSeeds = [
        "testnet-seed.bitcoinabc.org",
    ]

    let genesisBlock = Block(
            withHeader: BlockHeader(
                    version: 1,
                    previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                    merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                    timestamp: 1296688602,
                    bits: 486604799,
                    nonce: 414098458
            ),
            height: 0)

    let checkpointBlock = Block(
            withHeader: BlockHeader(
                    version: 536870912,
                    previousBlockHeaderReversedHex: "00000000000000e07429b8be0c135297a165c7637ef3941ab3d761a754b61392",
                    merkleRootReversedHex: "5ab6666b8a31e476e02e46fbe9b3cbae625ebd6514dedc78500340a478a026f0",
                    timestamp: 1535342611,
                    bits: 436465949,
                    nonce: 1510232395
            ),
            height: 1253952)

    required init(validatorFactory: BlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
    }

}
