import Foundation
import HSCryptoX11

class DashTestNet: INetwork {
    let protocolVersion: Int32 = 70213

    let name = "dash-main-net"

    let maxBlockSize: UInt32 = 1_000_000_000
    let pubKeyHash: UInt8 = 0x8c
    let privateKey: UInt8 = 0x80
    let scriptHash: UInt8 = 0x13
    let pubKeyPrefixPattern: String = "y"
    let scriptPrefixPattern: String = "8|9"
    let bech32PrefixPattern: String = "bc"
    let xPubKey: UInt32 = 0x0488b21e
    let xPrivKey: UInt32 = 0x0488ade4
    let magic: UInt32 = 0xcee2caff
    let port: UInt32 = 19999
    let coinType: UInt32 = 1
    let sigHash: SigHashType = .bitcoinAll
    var syncableFromApi: Bool = true

    let dnsSeeds = [
        "testnet-seed.dashdot.io",
        "test.dnsseed.masternode.io"
    ]

    var genesisBlock: Block {
        return Block(
            withHeader: BlockHeader(
                    version: 1,
                    headerHash: "00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c".reversedData!,
                    previousBlockHeaderHash: "0000000000000000000000000000000000000000000000000000000000000000".reversedData!,
                    merkleRoot: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".reversedData!,
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
                        headerHash: "0000000f10a125d1d97784028be7c3b737e21a3ab76d59a60f8d244ab548de14".reversedData!,
                        previousBlockHeaderHash: "00000025a533a276a43aaacc27d44f1e599f07fde18b8348c1355a9bcf0ea339".reversedData!,
                        merkleRoot: "fe39bdb86999ba1eaca10e56bf12528c9cce278c8dde66f399605d8e79e12fe6".reversedData!,
                        timestamp: 1551699279,
                        bits: 0x1d312d59,
                        nonce: 4281733120
                ),
                height: 55032)
    }
    required init() {
//        self.blockHelper = blockHelper
//
//        headerValidator = validatorFactory.validator(for: .header)
//        difficultyValidator = validatorFactory.validator(for: .DGW)
    }

    func validate(block: Block, previousBlock: Block) throws {
//        try headerValidator.validate(candidate: block, block: previousBlock, network: self)
//        if blockHelper.previous(for: previousBlock, index: 24) == nil {                        //TODO: Remove trust first 24 block  in dash
//            return
//        }
//        try difficultyValidator.validate(candidate: block, block: previousBlock, network: self)
    }

    func generateBlockHeaderHash(from data: Data) -> Data {
        return CryptoX11.x11(from: data)
    }

}
