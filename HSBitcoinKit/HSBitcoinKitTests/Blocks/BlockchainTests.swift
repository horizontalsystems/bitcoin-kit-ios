import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import HSBitcoinKit

class BlockchainTest: XCTestCase {

    private var mockNetwork: MockINetwork!
    private var mockFactory: MockIFactory!
    private var mockBlockchainDataListener: MockIBlockchainDataListener!

    private var realm: Realm!
    private var blockchain: Blockchain!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write {
            realm.deleteAll()
        }

        mockNetwork = MockINetwork()
        mockFactory = MockIFactory()
        mockBlockchainDataListener = MockIBlockchainDataListener()

        stub(mockNetwork) { mock in
            when(mock.validate(block: any(), previousBlock: any())).thenDoNothing()
        }

        stub(mockBlockchainDataListener) { mock in
            when(mock.onUpdate(updated: any(), inserted: any())).thenDoNothing()
            when(mock.onDelete(transactionHashes: any())).thenDoNothing()
            when(mock.onInsert(block: any())).thenDoNothing()
        }

        blockchain = Blockchain(network: mockNetwork, factory: mockFactory, listener: mockBlockchainDataListener)
    }

    override func tearDown() {
        mockNetwork = nil
        mockFactory = nil
        mockBlockchainDataListener = nil

        realm = nil
        blockchain = nil

        super.tearDown()
    }

    func testConnect_ExistingBlock() {
        let merkleBlock = MerkleBlock(header: TestData.checkpointBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let block = Block(withHeader: TestData.checkpointBlock.header!, height: 0)

        try! realm.write {
            realm.add(block)
        }

        let connectedBlock = try! blockchain.connect(merkleBlock: merkleBlock, realm: realm)

        verifyNoMoreInteractions(mockBlockchainDataListener)

        XCTAssertEqual(connectedBlock, block)
        XCTAssertEqual(realm.objects(Block.self).count, 1)
    }

    func testConnect_NewBlockInChain() {
        let block = Block(withHeader: TestData.checkpointBlock.header!, height: 0)
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, previousBlock: block)

        try! realm.write {
            realm.add(block)
        }

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))).thenReturn(newBlock)
        }

        XCTAssertEqual(realm.objects(Block.self).count, 1)

        var connectedBlock: Block!
        try! realm.write {
            connectedBlock = try! blockchain.connect(merkleBlock: merkleBlock, realm: realm)
        }

        verify(mockFactory).block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))
        verify(mockBlockchainDataListener).onInsert(block: equal(to: newBlock))

        XCTAssertEqual(connectedBlock!.headerHash, newBlock.headerHash)
        XCTAssertEqual(connectedBlock!.previousBlock, block)
        XCTAssertEqual(connectedBlock.stale, true)
        XCTAssertEqual(realm.objects(Block.self).count, 2)
    }

    func testConnect_NewBlockNotInChain() {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())

        do {
            try realm.write {
                let _ = try blockchain.connect(merkleBlock: merkleBlock, realm: realm)
            }
            XCTFail("Should throw exception")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
        } catch {
            XCTFail("Unexpected exception thrown")
        }
        verifyNoMoreInteractions(mockBlockchainDataListener)

        XCTAssertEqual(realm.objects(Block.self).count, 0)
    }

    func testConnect_NewInvalidBlock() {
        let block = Block(withHeader: TestData.checkpointBlock.header!, height: 0)
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, previousBlock: block)

        try! realm.write {
            realm.add(block)
        }

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))).thenReturn(newBlock)
        }
        stub(mockNetwork) { mock in
            when(mock.validate(block: any(), previousBlock: any())).thenThrow(BlockValidatorError.wrongPreviousHeaderHash)
        }

        do {
            try realm.write {
                let _ = try blockchain.connect(merkleBlock: merkleBlock, realm: realm)
            }
            XCTFail("Should throw exception")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.wrongPreviousHeaderHash)
        } catch {
            XCTFail("Unexpected exception thrown")
        }

        verifyNoMoreInteractions(mockBlockchainDataListener)
    }

    func testForceAdd() {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, height: 1)

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), height: equal(to: 1))).thenReturn(newBlock)
        }

        try! realm.write {
            let _ = blockchain.forceAdd(merkleBlock: merkleBlock, height: 1, realm: realm)
        }

        verify(mockNetwork, never()).validate(block: any(), previousBlock: any())
        verify(mockBlockchainDataListener).onInsert(block: equal(to: newBlock))

        let realmBlocks = realm.objects(Block.self)
        XCTAssertEqual(realmBlocks.count, 1)
        XCTAssertEqual(realmBlocks.last!.headerHash, merkleBlock.headerHash)
    }

    func testHandleFork_noFork() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [4: "11111114", 5: "11111115", 6: "11111116"]

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)


        blockchain.handleFork(realm: realm)

        assertBlocksPresent(blocks: blocksInChain, realm: realm)
        assertNotStaleBlocksPresent(realm: realm)
    }

    func testHandleFork_forkExists_newBlocksLonger() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)

        blockchain.handleFork(realm: realm)

        assertBlocksPresent(blocks: [1: "00000001"], realm: realm)
        assertBlocksNotPresent(blocks: [2: "00000002", 3: "00000003"], realm: realm)
        assertNotStaleBlocksPresent(realm: realm)
    }

    func testHandleFork_forkExists_newBlocksShorter() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003", 4: "00000004"]
        let newBlocks = [2: "11111112", 3: "11111113"]

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)

        blockchain.handleFork(realm: realm)

        assertBlocksPresent(blocks: blocksInChain, realm: realm)
        assertBlocksNotPresent(blocks: newBlocks, realm: realm)
    }

    func testHandleFork_forkExists_newBlocksEqual() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [2: "11111112", 3: "11111113"]

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)

        blockchain.handleFork(realm: realm)

        assertBlocksPresent(blocks: blocksInChain, realm: realm)
        assertBlocksNotPresent(blocks: newBlocks, realm: realm)
    }

    func testHandleFork_noNewBlocks() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [Int: String]()

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)

        blockchain.handleFork(realm: realm)

        assertBlocksPresent(blocks: blocksInChain, realm: realm)
    }

    func testHandleFork_forkExists_noBlocksInChain() {
        let blocksInChain = [Int: String]()
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        prefillBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks)

        blockchain.handleFork(realm: realm)

        assertNotStaleBlocksPresent(realm: realm)
    }

    func testRemoveBlocks() {
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        prefillBlocks(blocksInChain: [Int: String](), newBlocks: newBlocks)

        let hashes = Array(realm.objects(Block.self)).compactMap { $0.reversedHeaderHashHex }

        try! realm.write {
            blockchain.deleteBlocks(blocks: realm.objects(Block.self), realm: realm)
        }

        verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: hashes))
        assertBlocksNotPresent(blocks: newBlocks, realm: realm)
    }

    private func assertBlocksPresent(blocks: [Int: String], realm: Realm) {
        for (height, id) in blocks {
            if realm.objects(Block.self).filter("height = %@ AND headerHash = %@", height, Data(hex: id)!).count == 0 {
                XCTFail("Block \(id)(\(height)) not found")
            }

            if realm.objects(Transaction.self).filter("dataHash = %@", Data(hex: id)!).count == 0 {
                XCTFail("Transaction \(id) not found")
            }
        }
    }

    private func assertBlocksNotPresent(blocks: [Int: String], realm: Realm) {
        for (height, id) in blocks {
            if realm.objects(Block.self).filter("height = %@ AND headerHash = %@", height, Data(hex: id)!).count > 0 {
                XCTFail("Block \(id)(\(height)) should not present")
            }

            if realm.objects(Transaction.self).filter("dataHash = %@", Data(hex: id)!).count > 0 {
                XCTFail("Transaction \(id) should not present")
            }
        }
    }

    private func assertNotStaleBlocksPresent(realm: Realm) {
        if realm.objects(Block.self).filter("stale = %@", true).count > 0 {
            XCTFail("Stale blocks found!")
        }
    }

    private func prefillBlocks(blocksInChain: [Int: String], newBlocks: [Int: String]) {
        try! realm.write {
            for (height, id) in blocksInChain {
                let block = Block(withHeaderHash: Data(hex: id)!, height: height)
                block.stale = false
                realm.add(block)

                let transaction = TestData.p2pkTransaction
                transaction.dataHash = block.headerHash
                transaction.reversedHashHex = block.headerHash.reversedHex
                transaction.block = block
                realm.add(transaction)
            }

            for (height, id) in newBlocks {
                let block = Block(withHeaderHash: Data(hex: id)!, height: height)
                block.stale = true
                realm.add(block)

                let transaction = TestData.p2pkTransaction
                transaction.dataHash = block.headerHash
                transaction.reversedHashHex = block.headerHash.reversedHex
                transaction.block = block
                realm.add(transaction)
            }
        }
    }

}
