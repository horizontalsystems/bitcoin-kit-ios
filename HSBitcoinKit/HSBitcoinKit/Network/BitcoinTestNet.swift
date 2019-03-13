import Foundation

class BitcoinTestNet: INetwork {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    private let headerValidator: IBlockValidator
    private let bitsValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let testNetDifficultyValidator: IBlockValidator

    let merkleBlockValidator: IMerkleBlockValidator

    let name = "bitcoin-test-net"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let pubKeyPrefixPattern: String = "m|n"
    let scriptPrefixPattern: String = "2"
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

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943".reversedData,
                        previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                        merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                        timestamp: 1296688602,
                        bits: 486604799,
                        nonce: 414098458
                ),
                height: 0)
    }

    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 2079170560,
                        headerHash: "00000000000002c23115a5766fc00c93711b30a8d2b8e6dde870c20da4d3e2fe".reversedData,
                        previousBlockHeaderReversedHex: "00000000000007524a71cc81cadbd1ddf9d38848fa8081ad2a72eade4b70d1c1",
                        merkleRootReversedHex: "975b76235d1a9b97fbf4a4f203a762728fb404d568dd33921e328e2d5a712c46",
                        timestamp: 1550688527,
                        bits: 436465680,
                        nonce: 489544448
                ),
                height: 1479744)
    }

    required init(validatorFactory: IBlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)
        bitsValidator = validatorFactory.validator(for: .bits)
        legacyDifficultyValidator = validatorFactory.validator(for: .legacy)
        testNetDifficultyValidator = validatorFactory.validator(for: .testNet)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 1_000_000)
    }

    func validate(block: Block, previousBlock: Block) throws {
        guard let previousBlockHeader = previousBlock.header else {
            throw Block.BlockError.noHeader
        }

        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
        if isDifficultyTransitionPoint(height: block.height) {
            try legacyDifficultyValidator.validate(candidate: block, block: previousBlock, network: self)
        } else {
            if previousBlockHeader.timestamp > BitcoinTestNet.testNetDiffDate {
                try testNetDifficultyValidator.validate(candidate: block, block: previousBlock, network: self)
            } else {
                try bitsValidator.validate(candidate: block, block: previousBlock, network: self)
            }
        }
    }

}
