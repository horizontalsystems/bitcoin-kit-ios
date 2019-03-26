import Foundation

class BitcoinMainNet: INetwork {
    private let headerValidator: IBlockValidator
    private let bitsValidator: IBlockValidator
    private let difficultyValidator: IBlockValidator

    let merkleBlockValidator: IMerkleBlockValidator

    let name = "bitcoin-main-net"
    let pubKeyHash: UInt8 = 0x00
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x05
    let pubKeyPrefixPattern: String = "1"
    let scriptPrefixPattern: String = "3"
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xf9beb4d9
    let port: UInt32 = 8333
    let coinType: UInt32 = 0
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "seed.bitcoin.sipa.be",         // Pieter Wuille
        "dnsseed.bluematt.me",          // Matt Corallo
        "dnsseed.bitcoin.dashjr.org",   // Luke Dashjr
        "seed.bitcoinstats.com",        // Chris Decker
        "seed.bitnodes.io",             // Addy Yeow
        "seed.bitcoin.jonasschnelli.ch",// Jonas Schnelli
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f".reversedData!,
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
                        version: 536870912,
                        headerHash: "0000000000000000002567dc317da20ddb0d7ef922fe1f9c2375671654f9006c".reversedData!,
                        previousBlockHeaderReversedHex: "00000000000000000017e5c36734296b27065045f181e028c0d91cebb336d50c",
                        merkleRootReversedHex: "2f9963d6eb332a0dd03ad806f504981e6180226dbca4385dc801db8974b2c17b",
                        timestamp: 1551026038,
                        bits: 388914000,
                        nonce: 1427093839
                ),
                height: 564480)
    }

    required init(validatorFactory: IBlockValidatorFactory, merkleBranch: IMerkleBranch) {
        headerValidator = validatorFactory.validator(for: .header)
        bitsValidator = validatorFactory.validator(for: .bits)
        difficultyValidator = validatorFactory.validator(for: .legacy)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 1_000_000, merkleBranch: merkleBranch)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
        if isDifficultyTransitionPoint(height: block.height) {
            try difficultyValidator.validate(candidate: block, block: previousBlock, network: self)
        } else {
            try bitsValidator.validate(candidate: block, block: previousBlock, network: self)
        }
    }

}
