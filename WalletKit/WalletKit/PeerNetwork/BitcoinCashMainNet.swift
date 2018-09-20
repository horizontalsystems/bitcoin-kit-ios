import Foundation

class BitcoinCashMainNet: NetworkProtocol {
    private static let diffDate = 1510600000 //  2017 November 3, 14:06 GMT

    private let headerValidator: IBlockValidator
    private let bitsValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let dAAValidator: IBlockValidator
    private let eDAValidator: IBlockValidator

    private let blockHelper: BlockHelper

    let name = "bitcoin-cash-main-net"
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let pubKeyPrefixPattern: String = "q"
    let scriptPrefixPattern: String = "p"
    let bech32PrefixPattern: String = "bitcoincash"
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

    var targetTimeSpan: Int { return 24 * 60 * 60 }                     // Seconds in Bitcoin cycle
    var targetSpacing: Int { return 10 * 60 }                           // 10 min. for mining 1 Block

    required init(validatorFactory: BlockValidatorFactory, blockHelper: BlockHelper) {
        self.blockHelper = blockHelper
        headerValidator = validatorFactory.validator(for: .header)
        bitsValidator = validatorFactory.validator(for: .bits)
        legacyDifficultyValidator = validatorFactory.validator(for: .legacy)
        dAAValidator = validatorFactory.validator(for: .DAA)
        eDAValidator = validatorFactory.validator(for: .EDA)
    }

    func validate(block: Block, previousBlock: Block) throws {
//        try headerValidator.validate(candidate: block, block: previousBlock, network: self)

//        if try dAAValidator.medianTimePast(block: block) >= BitcoinCashMainNet.diffDate {
            try dAAValidator.validate(candidate: block, block: previousBlock, network: self)
//        } else {
//            if isDifficultyTransitionPoint(height: previousBlock.height) {
//                try legacyDifficultyValidator.validate(candidate: block, block: previousBlock, network: self)
//            } else {
//                try eDAValidator.validate(candidate: block, block: previousBlock, network: self)
//            }
//        }
    }

}