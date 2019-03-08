import Foundation
import HSCryptoX11

class DashTestNet: INetwork {
    private let headerValidator: IBlockValidator
    private let difficultyValidator: IBlockValidator
    private let blockHelper: IBlockHelper

    let merkleBlockValidator: IMerkleBlockValidator
    let protocolVersion: Int32 = 70213

    let name = "dash-main-net"
    let pubKeyHash: UInt8 = 0x8c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x13
    let pubKeyPrefixPattern: String = "1"
    let scriptPrefixPattern: String = "3"
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xcee2caff
    let port: UInt32 = 19999
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    var maxTargetBits = 0x1e0fffff
    var targetTimeSpan = 600                          // 10 min for 24 blocks
    var targetSpacing = 150                           // 2.5 min. for mining 1 Block

    let dnsSeeds = [
        "testnet-seed.dashdot.io",
        "test.dnsseed.masternode.io"
    ]

    let genesisBlock = Block(
            withHeader: BlockHeader(
                    version: 1,
                    headerHash: "00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c".reversedData,
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
                    headerHash: "00000c047c7aa022871971bf7e2c066bbb5df64de1dd673495451a38e9bf167f".reversedData,
                    previousBlockHeaderReversedHex: "00000ce22113f3eb8636e225d6a1691e132fdd587aed993e1bc9b07a0235eea4",
                    merkleRootReversedHex: "53508abc886ee283341105a6366f78c82b22d442c9e8d42ec89c11a7b6460667",
                    timestamp: 1544736446,
                    bits: 0x1e0fffff,
                    nonce: 24357
            ),
            height: 4001)

    required init(validatorFactory: IBlockValidatorFactory, blockHelper: IBlockHelper) {
        self.blockHelper = blockHelper

        headerValidator = validatorFactory.validator(for: .header)
        difficultyValidator = validatorFactory.validator(for: .DGW)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 1_000_000_000)
    }

    func validate(block: Block, previousBlock: Block) throws {
        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
        if blockHelper.previous(for: previousBlock, index: 24) == nil {                        //TODO: Remove trust first 24 block  in dash
            return
        }
        try difficultyValidator.validate(candidate: block, block: previousBlock, network: self)
    }

    func generateBlockHeaderHash(from data: Data) -> Data {
        return CryptoX11.x11(from: data)
    }

}
