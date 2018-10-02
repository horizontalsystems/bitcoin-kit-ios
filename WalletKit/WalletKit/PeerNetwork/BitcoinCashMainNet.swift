import Foundation

class BitcoinCashMainNet: NetworkProtocol {
    private static let diffDate = 1510600000 //  2017 November 3, 14:06 GMT

    private let headerValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let dAAValidator: IBlockValidator
    private let eDAValidator: IBlockValidator

    let merkleBlockValidator: MerkleBlockValidator

    private let blockHelper: BlockHelper

    let name = "bitcoin-cash-main-net"
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let pubKeyPrefixPattern: String = "1"
    let scriptPrefixPattern: String = "3"
    let bech32PrefixPattern: String = "bitcoincash"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xe3e1f3e8
    let port: UInt32 = 8333
    let coinType: UInt32 = 0
    let maxBlockSize: UInt32 = 32 * 1024 * 1024

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

//    One of the checkpoint blocks before hard fork. Must be tested
//    let checkpointBlock = Block(
//            withHeader: BlockHeader(
//                    version: 536870912,
//                    previousBlockHeaderReversedHex: "000000000000000000b3ff31d54e9e83515ee18360c7dc59e30697d083c745ff",
//                    merkleRootReversedHex: "33d4a902daa28d09f9f6a319f538153e4b747938e20e113a2935c8dc0b971584",
//                    timestamp: 1481765313,
//                    bits: 0x18038b85,
//                    nonce: 251583942
//            ),
//            height: 443520)

    let checkpointBlock = Block(
            withHeader: BlockHeader(
                    version: 536870912,
                    previousBlockHeaderReversedHex: "000000000000000000640772774c4c5c923397129370c8edf05c3792de1dcb4e",
                    merkleRootReversedHex: "bf78c4852c6fb6a80f47b254dd076e780872958dcaac629e48ba297b7cb5782a",
                    timestamp: 1535106119,
                    bits: 0x180215b2,
                    nonce: 2725498692
            ),
            height: 544800)

//    var targetTimeSpan: Int { return 24 * 60 * 60 }                     // Seconds in Bitcoin cycle

    required init(validatorFactory: BlockValidatorFactory, blockHelper: BlockHelper) {
        self.blockHelper = blockHelper
        headerValidator = validatorFactory.validator(for: .header)
        legacyDifficultyValidator = validatorFactory.validator(for: .legacy)
        dAAValidator = validatorFactory.validator(for: .DAA)
        eDAValidator = validatorFactory.validator(for: .EDA)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 32 * 1024 * 1024)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
        if try blockHelper.medianTimePast(block: block) >= BitcoinCashMainNet.diffDate {            //TODO: change medianTime to number of needed block
            if blockHelper.previous(for: previousBlock, index: 147) == nil {                        //TODO: Remove trust first 147 block (144 + 3) in bitcoin cash
                return
            }
            try dAAValidator.validate(candidate: block, block: previousBlock, network: self)
        } else {
            if isDifficultyTransitionPoint(height: block.height) {
                try legacyDifficultyValidator.validate(candidate: block, block: previousBlock, network: self)
            } else {
                try eDAValidator.validate(candidate: block, block: previousBlock, network: self)
            }
        }
    }

}