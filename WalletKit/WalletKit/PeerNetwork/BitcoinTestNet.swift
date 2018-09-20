import Foundation

class BitcoinTestNet: NetworkProtocol {
    private static let testNetDiffDate = 1329264000 // February 16th 2012

    private let headerValidator: IBlockValidator
    private let bitsValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let testNetDifficultyValidator: IBlockValidator

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
                    previousBlockHeaderReversedHex: "00000000000000a5bf9029aebb1956200304ffee31bc09f1323ae412d81fa2b2",
                    merkleRootReversedHex: "dff076f1f3468f86785b42c10e6f23c849ccbc1d40a0fa8909b20b20fb204de2",
                    timestamp: 1535560970,
                    bits: 424329477,
                    nonce: 2681700833
            ),
            height: 1411200)

    required init(validatorFactory: BlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)
        bitsValidator = validatorFactory.validator(for: .bits)
        legacyDifficultyValidator = validatorFactory.validator(for: .legacy)
        testNetDifficultyValidator = validatorFactory.validator(for: .testNet)
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
