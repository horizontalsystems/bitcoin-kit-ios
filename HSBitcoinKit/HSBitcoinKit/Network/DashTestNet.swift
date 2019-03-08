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
    var targetTimeSpan = 3600                          // 1 hour for 24 blocks
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
                    headerHash: "0000000f10a125d1d97784028be7c3b737e21a3ab76d59a60f8d244ab548de14".reversedData,
                    previousBlockHeaderReversedHex: "00000025a533a276a43aaacc27d44f1e599f07fde18b8348c1355a9bcf0ea339",
                    merkleRootReversedHex: "fe39bdb86999ba1eaca10e56bf12528c9cce278c8dde66f399605d8e79e12fe6",
                    timestamp: 1551699279,
                    bits: 0x1d312d59,
                    nonce: 4281733120
            ),
            height: 55032)

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
