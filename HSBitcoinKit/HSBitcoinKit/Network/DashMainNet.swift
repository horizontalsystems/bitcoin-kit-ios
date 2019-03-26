import Foundation
import HSCryptoX11

class DashMainNet: INetwork {
    private let headerValidator: IBlockValidator
    private let difficultyValidator: IBlockValidator
    private let blockHelper: IBlockHelper

    let merkleBlockValidator: IMerkleBlockValidator
    let protocolVersion: Int32 = 70213

    let name = "dash-main-net"
    let pubKeyHash: UInt8 = 0x4c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x10
    let pubKeyPrefixPattern: String = "X"
    let scriptPrefixPattern: String = "7"
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xbf0c6bbd
    let port: UInt32 = 9999
    let coinType: UInt32 = 5
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    var maxTargetBits: Int { return 0x1e0fffff }
    var targetTimeSpan = 3600                          // 1 hour for 24 blocks
    var targetSpacing = 150                           // 2.5 min. for mining 1 Block

    let dnsSeeds = [
        "dnsseed.dash.org",
        "dnsseed.dashdot.io",
        "dnsseed.masternode.io",
    ]

    var genesisBlock: Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "00000ffd590b1485b3caadc19b22e6379c733355108f107a430458cdf3407ab6".reversedData,
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
                        headerHash: "00000000000000243001bbc7deafb49dc28738204d8a237852aacb19cb262474".reversedData,
                        previousBlockHeaderReversedHex: "000000000000000992e45d7b6d5204e40b24474db7c107e7b1e4884f3e76462c",
                        merkleRootReversedHex: "61694834cfd431c70975645849caff2e1bfb4c487706cf217129fd4371cd7a79",
                        timestamp: 1551689319,
                        bits: 0x193f7bf8,
                        nonce: 2813674015
                ),
                height: 1030968)
    }

    required init(validatorFactory: IBlockValidatorFactory, blockHelper: IBlockHelper, merkleBranch: IMerkleBranch) {
        self.blockHelper = blockHelper
        headerValidator = validatorFactory.validator(for: .header)
        difficultyValidator = validatorFactory.validator(for: .DGW)

        merkleBlockValidator = MerkleBlockValidator(maxBlockSize: 2_000_000_000, merkleBranch: merkleBranch)
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
