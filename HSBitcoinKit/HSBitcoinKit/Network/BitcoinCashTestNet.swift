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
                    previousBlockHeaderReversedHex: "000000000000043c25d4b23dee40208a9df99ef5717d236379120b01af2077e2",
                    merkleRootReversedHex: "fb7ca6fbd9e1dd307cdafa7f7bf66317a49bfae4fc8e4d841f4faaf1acae5844",
                    timestamp: 1543989687,
                    bits: 486604799,
                    nonce: 890299933
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
