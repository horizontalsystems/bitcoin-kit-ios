import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import WalletKit

class BlockChainBuilderTest: XCTestCase {

    private var mockNetwork: MockNetworkProtocol!
    private var mockFactory: MockFactory!
    private var builder: Blockchain!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockNetwork = mockWalletKit.mockNetwork
        mockFactory = mockWalletKit.mockFactory
        realm = mockWalletKit.realm

        builder = Blockchain(network: mockNetwork, factory: mockFactory)
    }

    override func tearDown() {
        mockNetwork = nil
        mockFactory = nil
        realm = nil
        builder = nil

        super.tearDown()
    }

//    func testHandle_emptyDB_EmptyBlocks() {
//        do {
//            let _ = try builder.getLastBlock(fromMerkleBlocks: [], realm: realm)
//            XCTFail("Should raise exception")
//        } catch let error as Blockchain.BlockchainBuildError {
//            XCTAssertEqual(error, Blockchain.BlockchainBuildError.emptyMerkleBlocks)
//        } catch {
//            XCTFail("Invalid Exception thrown")
//        }
//    }
//
//    func testHandle_emptyDB_singleOrphanBlock() {
//        let prevHash = Data(count: 55)
//        let blockHeader = TestData.firstBlock.header!
//        let invalidMerkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [Data](), transactions: [Transaction]())
//
//        blockHeader.previousBlockHeaderHash = prevHash
//        let merkleBlocks = [invalidMerkleBlock]
//
//        do {
//            let _ = try builder.getLastBlock(fromMerkleBlocks: merkleBlocks, realm: realm)
//            XCTFail("Should raise exception")
//        } catch let error as BlockValidatorError {
//            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
//        } catch {
//            XCTFail("Invalid Exception thrown")
//        }
//    }
//
//    func testHandle_emptyDB_singleOrphanBlock_nextInChain() {
//        let newBlock = TestData.firstBlock
//        let blockHeader = newBlock.header!
//        let checkpointBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", TestData.checkpointBlock.reversedHeaderHashHex).first!
//        let transaction = TestData.p2pkTransaction
//        let validMerkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [Data(count: 32)], transactions: [transaction])
//
//        blockHeader.previousBlockHeaderHash = checkpointBlock.headerHash
//        newBlock.previousBlock = checkpointBlock
//
//        stub(mockNetwork) { mock in
//            when(mock.validate(block: any(), previousBlock: any())).thenDoNothing()
//        }
//        stub(mockFactory) { mock in
//            when(mock.block(withHeader: equal(to: blockHeader), previousBlock: equal(to: checkpointBlock))).thenReturn(newBlock)
//        }
//
//        let merkleBlocks = [validMerkleBlock]
//        let blocks = try! builder.getLastBlock(fromMerkleBlocks: merkleBlocks, realm: realm)
//
//        verify(mockNetwork).validate(block: equal(to: newBlock), previousBlock: equal(to: checkpointBlock))
//        XCTAssertEqual(blocks.count, 1)
//        XCTAssertEqual(blocks[newBlock.reversedHeaderHashHex], newBlock)
//    }

}
