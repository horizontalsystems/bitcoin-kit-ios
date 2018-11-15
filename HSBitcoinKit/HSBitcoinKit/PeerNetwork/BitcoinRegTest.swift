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

    let dnsSeeds = [
         "btc-regtest.horizontalsystems.xyz",
         "btc01-regtest.horizontalsystems.xyz",
         "btc02-regtest.horizontalsystems.xyz",
         "btc03-regtest.horizontalsystems.xyz",
    ]

    let genesisBlock = Block(
            withHeader: BlockHeader(
                    version: 1,
                    previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                    merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                    timestamp: 1296688602,
                    bits: 545259519,
                    nonce: 2
            ),
            height: 0)

    let checkpointBlock = Block(
            withHeader: BlockHeader(
                    version: 1,
                    previousBlockHeaderReversedHex: "0000000000000000000000000000000000000000000000000000000000000000",
                    merkleRootReversedHex: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
                    timestamp: 1296688602,
                    bits: 545259519,
                    nonce: 2
            ),
            height: 0)

//    let checkpointBlock = Block(
//            withHeader: BlockHeader(
//                    version: 536870912,
//                    previousBlockHeaderReversedHex: "5dc07110c9986c22d0cf760b68dfec769da89e465c73eb08b0b8bd7a7e9e4743",
//                    merkleRootReversedHex: "1d9bb98732dad67e431d1983d368a389cb73dbcc495b06de7cd26c9dddccab60",
//                    timestamp: 1536572186,
//                    bits: 545259519,
//                    nonce: 0
//            ),
//            height: 2016)

    required init(validatorFactory: IBlockValidatorFactory) {
        headerValidator = validatorFactory.validator(for: .header)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 1_000_000)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
    }

}
