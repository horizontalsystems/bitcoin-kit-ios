import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import HSBitcoinKit

class BlockchainTest: XCTestCase {

    private var mockStorage: MockIStorage!
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

        mockStorage = MockIStorage()
        mockNetwork = MockINetwork()
        mockFactory = MockIFactory()
        mockBlockchainDataListener = MockIBlockchainDataListener()

        stub(mockStorage) { mock in
            when(mock.inTransaction(_: any())).then({ try? $0(self.realm) })
            when(mock.add(block: any(), realm: any())).thenDoNothing()
            when(mock.update(block: any(), realm: any())).thenDoNothing()
            when(mock.delete(blocks: any(), realm: any())).thenDoNothing()
        }

        stub(mockNetwork) { mock in
            when(mock.validate(block: any(), previousBlock: any())).thenDoNothing()
        }

        stub(mockBlockchainDataListener) { mock in
            when(mock.onUpdate(updated: any(), inserted: any())).thenDoNothing()
            when(mock.onDelete(transactionHashes: any())).thenDoNothing()
            when(mock.onInsert(block: any())).thenDoNothing()
        }

        blockchain = Blockchain(storage: mockStorage, network: mockNetwork, factory: mockFactory, listener: mockBlockchainDataListener)
    }

    override func tearDown() {
        mockStorage = nil
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

        stub(mockStorage) { mock in
            when(mock.block(byHashHex: merkleBlock.reversedHeaderHashHex)).thenReturn(block)
        }

        let connectedBlock = try! blockchain.connect(merkleBlock: merkleBlock, realm: realm)

        XCTAssertEqual(connectedBlock, block)

        verify(mockStorage).block(byHashHex: merkleBlock.reversedHeaderHashHex)
        verifyNoMoreInteractions(mockBlockchainDataListener)
        verifyNoMoreInteractions(mockStorage)
    }

    func testConnect_NewBlockInChain() {
        let block = Block(withHeader: TestData.checkpointBlock.header!, height: 0)
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, previousBlock: block)

        stub(mockStorage) { mock in
            when(mock.block(byHashHex: merkleBlock.reversedHeaderHashHex)).thenReturn(nil)
            when(mock.block(byHashHex: merkleBlock.header.previousBlockHeaderHash.reversedHex)).thenReturn(block)
        }
        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))).thenReturn(newBlock)
        }

        let connectedBlock = try! blockchain.connect(merkleBlock: merkleBlock, realm: realm)

        verify(mockFactory).block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))
        verify(mockBlockchainDataListener).onInsert(block: equal(to: newBlock))
        verify(mockStorage).add(block: equal(to: newBlock), realm: any())

        XCTAssertEqual(connectedBlock.headerHash, newBlock.headerHash)
        XCTAssertEqual(connectedBlock.previousBlock, block)
        XCTAssertEqual(connectedBlock.stale, true)
    }

    func testConnect_NewBlockNotInChain() {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())

        stub(mockStorage) { mock in
            when(mock.block(byHashHex: merkleBlock.reversedHeaderHashHex)).thenReturn(nil)
            when(mock.block(byHashHex: merkleBlock.header.previousBlockHeaderHash.reversedHex)).thenReturn(nil)
        }

        do {
            _ = try blockchain.connect(merkleBlock: merkleBlock, realm: realm)
            XCTFail("Should throw exception")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
        } catch {
            XCTFail("Unexpected exception thrown")
        }
        verifyNoMoreInteractions(mockBlockchainDataListener)
        verify(mockStorage, never()).add(block: any(), realm: any())
    }

    func testConnect_NewInvalidBlock() {
        let block = Block(withHeader: TestData.checkpointBlock.header!, height: 0)
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, previousBlock: block)

        stub(mockStorage) { mock in
            when(mock.block(byHashHex: merkleBlock.reversedHeaderHashHex)).thenReturn(nil)
            when(mock.block(byHashHex: merkleBlock.header.previousBlockHeaderHash.reversedHex)).thenReturn(block)
        }
        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), previousBlock: equal(to: block))).thenReturn(newBlock)
        }
        stub(mockNetwork) { mock in
            when(mock.validate(block: any(), previousBlock: any())).thenThrow(BlockValidatorError.wrongPreviousHeaderHash)
        }

        do {
            _ = try blockchain.connect(merkleBlock: merkleBlock, realm: realm)
            XCTFail("Should throw exception")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.wrongPreviousHeaderHash)
        } catch {
            XCTFail("Unexpected exception thrown")
        }

        verifyNoMoreInteractions(mockBlockchainDataListener)
        verify(mockStorage, never()).add(block: any(), realm: any())
    }

    func testForceAdd() {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [Data](), transactions: [Transaction]())
        let newBlock = Block(withHeader: merkleBlock.header, height: 1)

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: merkleBlock.header), height: equal(to: 1))).thenReturn(newBlock)
        }

        _ = blockchain.forceAdd(merkleBlock: merkleBlock, height: 1, realm: realm)

        verify(mockNetwork, never()).validate(block: any(), previousBlock: any())
        verify(mockBlockchainDataListener).onInsert(block: equal(to: newBlock))
        verify(mockStorage).add(block: equal(to: newBlock), realm: any())
    }

    func testHandleFork_noFork() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [4: "11111114", 5: "11111115", 6: "11111116"]

        let mockedBlocks = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)

        blockchain.handleFork()

        let captor = ArgumentCaptor<Block>()
        verify(mockStorage, times(3)).update(block: captor.capture(), realm: any())
        for (ind, block) in mockedBlocks.newBlocks.enumerated() {
            XCTAssertEqual(captor.allValues[ind].stale, false)
            XCTAssertEqual(captor.allValues[ind].headerHash, block.headerHash)
        }
    }

    func testHandleFork_forkExists_newBlocksLonger() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        let mockedBlocks = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
        let inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 1))
        let inChainBlocksAfterForkTransactionHexes = Array(mockedBlocks.blocksInChainTransactionHexes.suffix(from: 1))

        blockchain.handleFork()

        verify(mockStorage).delete(blocks: equal(to: inChainBlocksAfterFork), realm: any())
        verify(mockStorage, never()).delete(blocks: equal(to: mockedBlocks.newBlocks), realm: any())
        verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: inChainBlocksAfterForkTransactionHexes))
    }

    func testHandleFork_forkExists_newBlocksShorter() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003", 4: "00000004"]
        let newBlocks = [2: "11111112", 3: "11111113"]

        let mockedBlocks = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
        let inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 2))

        blockchain.handleFork()

        verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks), realm: any())
        verify(mockStorage, never()).delete(blocks: equal(to: inChainBlocksAfterFork), realm: any())
        verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHexes))
    }

    func testHandleFork_forkExists_newBlocksEqual() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [2: "11111112", 3: "11111113"]

        let mockedBlocks = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)
        let inChainBlocksAfterFork = Array(mockedBlocks.blocksInChain.suffix(from: 1))

        blockchain.handleFork()

        verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks), realm: any())
        verify(mockStorage, never()).delete(blocks: equal(to: inChainBlocksAfterFork), realm: any())
        verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHexes))
    }

    func testHandleFork_noNewBlocks() {
        let blocksInChain = [1: "00000001", 2: "00000002", 3: "00000003"]
        let newBlocks = [Int: String]()

        _ = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)

        blockchain.handleFork()

        verify(mockStorage, never()).delete(blocks: any(), realm: any())
        verify(mockBlockchainDataListener, never()).onDelete(transactionHashes: any())
    }

    func testHandleFork_forkExists_noBlocksInChain() {
        let blocksInChain = [Int: String]()
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        let mockedBlocks = mockBlocks(blocksInChain: blocksInChain, newBlocks: newBlocks, mockStorage: mockStorage)

        blockchain.handleFork()

        verify(mockStorage, never()).delete(blocks: any(), realm: any())
        let captor = ArgumentCaptor<Block>()
        verify(mockStorage, times(3)).update(block: captor.capture(), realm: any())
        for (ind, block) in mockedBlocks.newBlocks.enumerated() {
            XCTAssertEqual(captor.allValues[ind].stale, false)
            XCTAssertEqual(captor.allValues[ind].headerHash, block.headerHash)
        }
    }

    func testRemoveBlocks() {
        let newBlocks = [2: "11111112", 3: "11111113", 4: "11111114"]

        let mockedBlocks = mockBlocks(blocksInChain: [Int: String](), newBlocks: newBlocks, mockStorage: mockStorage)

        blockchain.deleteBlocks(blocks: mockedBlocks.newBlocks, realm: realm)

        verify(mockStorage).delete(blocks: equal(to: mockedBlocks.newBlocks), realm: any())
        verify(mockBlockchainDataListener).onDelete(transactionHashes: equal(to: mockedBlocks.newBlocksTransactionHexes))
    }


    private func mockBlocks(blocksInChain: [Int: String], newBlocks: [Int: String], mockStorage: MockIStorage) -> MockedBlocks {
        var mockedBlocks = MockedBlocks()

        stub(mockStorage) { mock in
            for (height, id) in blocksInChain.sorted(by: { $0.key < $1.key }) {
                let block = Block(withHeaderHash: Data(hex: id)!, height: height)
                block.stale = false
                mockedBlocks.blocksInChain.append(block)

                let transaction = TestData.p2pkTransaction
                transaction.dataHash = block.headerHash
                transaction.reversedHashHex = block.headerHash.reversedHex
                transaction.block = block

                when(mock.transactions(ofBlock: equal(to: block), realm: any())).thenReturn([transaction])
                mockedBlocks.blocksInChainTransactionHexes.append(transaction.reversedHashHex)
            }

            for (height, id) in newBlocks.sorted(by: { $0.key < $1.key }) {
                let block = Block(withHeaderHash: Data(hex: id)!, height: height)
                block.stale = true
                mockedBlocks.newBlocks.append(block)

                let transaction = TestData.p2pkTransaction
                transaction.dataHash = block.headerHash
                transaction.reversedHashHex = block.headerHash.reversedHex
                transaction.block = block

                when(mock.transactions(ofBlock: equal(to: block), realm: any())).thenReturn([transaction])
                mockedBlocks.newBlocksTransactionHexes.append(transaction.reversedHashHex)
            }

            when(mock.blocks(stale: true, realm: any())).thenReturn(mockedBlocks.newBlocks)

            if let firstStale = mockedBlocks.newBlocks.first {
                when(mock.block(stale: true, sortedHeight: equal(to: "ASC"), realm: any())).thenReturn(firstStale)

                if let lastStale = mockedBlocks.newBlocks.last {
                    when(mock.block(stale: true, sortedHeight: "DESC", realm: any())).thenReturn(lastStale)

                    let inChainBlocksAfterForkPoint = mockedBlocks.blocksInChain.filter { $0.height >= firstStale.height }
                    when(mock.blocks(heightGreaterThanOrEqualTo: firstStale.height, stale: false, realm: any())).thenReturn(inChainBlocksAfterForkPoint)
                }
            } else {
                when(mock.block(stale: true, sortedHeight: equal(to: "ASC"), realm: any())).thenReturn(nil)
            }

            if let lastNotStale = mockedBlocks.blocksInChain.last {
                when(mock.block(stale: false, sortedHeight: "DESC", realm: any())).thenReturn(lastNotStale)
            } else {
                when(mock.block(stale: false, sortedHeight: "DESC", realm: any())).thenReturn(nil)
            }
        }

        return mockedBlocks
    }

    struct MockedBlocks {
        var newBlocks = [Block]()
        var blocksInChain = [Block]()
        var newBlocksTransactionHexes = [String]()
        var blocksInChainTransactionHexes = [String]()
    }

}
