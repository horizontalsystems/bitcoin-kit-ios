import Foundation

class BitcoinCashTestNet: INetwork {
    private let headerValidator: IBlockValidator

    let name = "bitcoin-cash-test-net"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let pubKeyPrefixPattern: String = "m|n"
    let scriptPrefixPattern: String = "2"
    let bech32PrefixPattern: String = "bchtest"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xf4e5f3f4
    let port: UInt32 = 18333
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let merkleBlockValidator: IMerkleBlockValidator

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
                    previousBlockHeaderReversedHex: "00000000213b5213663c4a91139f5a400c01b3eb8dd368c3c8b3c86fa6f7809e",
                    merkleRootReversedHex: "bbc68e26bf975f667bdd7fea497546244792a1bd3c3ff4aee87d7ff8ab10f423",
                    timestamp: 1545802380,
                    bits: 486604799,
                    nonce: 2980594562
            ),
            height: 1272398)

    required init(validatorFactory: IBlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 32 * 1024 * 1024)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
    }

}
