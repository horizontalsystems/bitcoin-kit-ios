import Foundation

class BitcoinTestNet: INetwork {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    private let headerValidator: IBlockValidator
    private let bitsValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let testNetDifficultyValidator: IBlockValidator

    let merkleBlockValidator: MerkleBlockValidator

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

    let dnsSeeds = [
        "testnet-seed.bitcoin.petertodd.org",    // Peter Todd
        "testnet-seed.bitcoin.jonasschnelli.ch", // Jonas Schnelli
        "testnet-seed.bluematt.me",              // Matt Corallo
        "testnet-seed.bitcoin.schildbach.de",    // Andreas Schildbach
        "bitcoin-testnet.bloqseeds.net",         // Bloq
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
                    previousBlockHeaderReversedHex: "00000000000001ade79216032b49854c966a1061fd3f8c6c56a0d38d0024629e",
                    merkleRootReversedHex: "e5221c3269c569c9eeb58cfcbca48041b08902567917860ac2216ffc051be8ca",
                    timestamp: 1539885052,
                    bits: 436304224,
                    nonce: 2919305209
            ),
            height: 1439424)

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
