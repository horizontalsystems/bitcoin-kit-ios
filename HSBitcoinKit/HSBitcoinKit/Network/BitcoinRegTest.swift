import Foundation

class BitcoinRegTest: INetwork {
    private let headerValidator: IBlockValidator

    let merkleBlockValidator: IMerkleBlockValidator

    let name = "bitcoin-reg-test"
    let pubKeyHash: UInt8 = 0x6f
    let privateKey: UInt8 = 0xef
    let scriptHash: UInt8 = 0xc4
    let pubKeyPrefixPattern: String = "m|n"
    let scriptPrefixPattern: String = "2"
    let bech32PrefixPattern: String = "bcrt"
    let xPubKey: UInt32 = 0x043587cf
    let xPrivKey: UInt32 = 0x04358394
    let magic: UInt32 = 0xfabfb5da
    let port: UInt32 = 18444
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = false

    let dnsSeeds = [
         "btc-regtest.horizontalsystems.xyz",
         "btc01-regtest.horizontalsystems.xyz",
         "btc02-regtest.horizontalsystems.xyz",
         "btc03-regtest.horizontalsystems.xyz",
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: nil,
                        previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                        merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                        timestamp: 1296688602,
                        bits: 545259519,
                        nonce: 2
                ),
                height: 0)
    }

    var checkpointBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: nil,
                        previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                        merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                        timestamp: 1296688602,
                        bits: 545259519,
                        nonce: 2
                ),
                height: 0)
    }

    required init(validatorFactory: IBlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 1_000_000)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
    }

}
