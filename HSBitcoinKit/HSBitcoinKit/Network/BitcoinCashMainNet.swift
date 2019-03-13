class BitcoinCashMainNet: INetwork {
    private static let diffDate = 1510600000 //  2017 November 3, 14:06 GMT

    private let headerValidator: IBlockValidator
    private let legacyDifficultyValidator: IBlockValidator
    private let dAAValidator: IBlockValidator
    private let eDAValidator: IBlockValidator

    let merkleBlockValidator: IMerkleBlockValidator

    private let blockHelper: IBlockHelper

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
    let sigHash: SigHashType = .bitcoinCashAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "seed.bitcoinabc.org",
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048".reversedData,
                        previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                        merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                        timestamp: 1231006505,
                        bits: 486604799,
                        nonce: 2083236893
                ),
                height: 0)
    }

    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 549453824,
                        headerHash: "00000000000000000356c9c3f92f22b88bd8d0544f40a09260235d6cf95d491b".reversedData,
                        previousBlockHeaderReversedHex: "000000000000000002e4009667ba236d52f605cd44c12ebd79208c14b520968e",
                        merkleRootReversedHex: "65822e3caa2a4709abd37df7de6464a58830da0f8e308af44586114e1c73914f",
                        timestamp: 1551084121,
                        bits: 403013590,
                        nonce: 2244691553
                ),
                height: 571268)
    }

//    var targetTimeSpan: Int { return 24 * 60 * 60 }                     // Seconds in Bitcoin cycle

    required init(validatorFactory: IBlockValidatorFactory, blockHelper: IBlockHelper) {
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
