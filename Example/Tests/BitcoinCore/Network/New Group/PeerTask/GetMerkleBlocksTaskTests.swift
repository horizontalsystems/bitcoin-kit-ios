//import XCTest
//import Cuckoo
//import HSCryptoKit
//@testable import BitcoinCore
//
//class GetMerkleBlockTaskTests:XCTestCase {
//
//    private var generatedDate: Date!
//    private var dateIsGenerated: Bool!
//    private var dateGenerator: (() -> Date)!
//
//    private var mockRequester: MockIPeerTaskRequester!
//    private var mockDelegate: MockIPeerTaskDelegate!
//
//    private var blockHashes: [BlockHash]!
//    private var blockHeaders: [BlockHeader]!
//    private var task: GetMerkleBlocksTask!
//
//    private let allowedIdleTime = 60.0
//
//    override func setUp() {
//        super.setUp()
//
//        dateIsGenerated = false
//        generatedDate = Date()
//        dateGenerator = {
//            self.dateIsGenerated = true
//            return self.generatedDate
//        }
//        mockRequester = MockIPeerTaskRequester()
//        mockDelegate = MockIPeerTaskDelegate()
//
//        stub(mockRequester) { mock in
//            when(mock).getData(items: any()).thenDoNothing()
//            when(mock).ping(nonce: any()).thenDoNothing()
//        }
//        stub(mockDelegate) { mock in
//            when(mock).handle(merkleBlock: any()).thenDoNothing()
//            when(mock).handle(failedTask: any(), error: any()).thenDoNothing()
//            when(mock).handle(completedTask: any()).thenDoNothing()
//        }
//
//        blockHeaders = [
//            BlockHeader(version: 0, headerHash: Data(repeating: 0, count: 32), previousBlockHeaderHash: Data(from: 100000), merkleRoot: "00011122".reversedData!, timestamp: 0, bits: 0, nonce: 0),
//            BlockHeader(version: 0, headerHash: Data(repeating: 1, count: 32), previousBlockHeaderHash: Data(from: 200000), merkleRoot: "00011122".reversedData!, timestamp: 0, bits: 0, nonce: 0)
//        ]
//        blockHashes = [
//            BlockHash(headerHash: blockHashes[0].headerHash, height: 10, order: 0),
//            BlockHash(headerHash: blockHashes[1].headerHash, height: 15, order: 0)
//        ]
//
//        task = GetMerkleBlocksTask(blockHashes: blockHashes, dateGenerator: dateGenerator)
//        task.requester = mockRequester
//        task.delegate = mockDelegate
//    }
//
//    override func tearDown() {
//        blockHashes = nil
//        task = nil
//
//        super.tearDown()
//    }
//
//    func testStart() {
//        task.start()
//
//        verify(mockRequester).getData(items: equal(to: [], equalWhen: { value, given in
//            return given.filter { inv in
//                return self.blockHashes.contains { blockHash in
//                    return blockHash.headerHash == inv.hash
//                }
//            }.count == given.count
//        }))
//        XCTAssertTrue(dateIsGenerated)
//    }
//
//    func testHandleMerkleBlock_BlockWasNotRequested() {
//        let blockHeader = BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(from: 300000), merkleRoot: "00011122".reversedData!, timestamp: 0, bits: 0, nonce: 0)
//        let merkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [], transactions: [])
//
//        let handled = task.handle(merkleBlock: merkleBlock)
//        XCTAssertFalse(handled)
//        XCTAssertFalse(dateIsGenerated)
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleMerkleBlock_CompleteMerkleBlock_BlockHashHasHeight() {
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//
//        let handled = task.handle(merkleBlock: merkleBlock)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        XCTAssertEqual(merkleBlock.height, blockHashes[0].height)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleMerkleBlock_CompleteMerkleBlock_BlockHashHeightIsZero() {
//        blockHashes[0] = BlockHash(headerHash: blockHashes[0].headerHash, height: 0, order: blockHashes[0].sequence)
//        task = GetMerkleBlocksTask(blockHashes: blockHashes, dateGenerator: dateGenerator)
//        task.requester = mockRequester
//        task.delegate = mockDelegate
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//
//        let handled = task.handle(merkleBlock: merkleBlock)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        XCTAssertEqual(merkleBlock.height, nil)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleMerkleBlock_CompleteMerkleBlock_SameBlockRepeated() {
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//
//        let handled = task.handle(merkleBlock: merkleBlock)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
//        verifyNoMoreInteractions(mockDelegate)
//
//        let handled2 = task.handle(merkleBlock: merkleBlock)
//
//        XCTAssertEqual(handled2, false)
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleMerkleBlock_CompleteMerkleBlock_AllBlocksReceived() {
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        resetMockDelegate()
//        dateIsGenerated = false
//
//        let handled2 = task.handle(merkleBlock: merkleBlock2)
//
//        XCTAssertTrue(handled2)
//        XCTAssertTrue(dateIsGenerated)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock2))
//        verify(mockDelegate).handle(completedTask: equal(to: task))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleMerkleBlock_MerkleBlockWithTransactions() {
//        let transaction = TestData.p2pkTransaction
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.header.dataHash], transactions: [])
//
//        let handled = task.handle(merkleBlock: merkleBlock)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleTransaction_NotInPendingMerkleBlocks() {
//        let transaction = TestData.p2pkTransaction
//        let transaction2 = TestData.p2pkhTransaction
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.header.dataHash], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        dateIsGenerated = false
//        let handled = task.handle(transaction: transaction2)
//
//        XCTAssertFalse(handled)
//        XCTAssertFalse(dateIsGenerated)
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleTransaction_CompletesPendingMerkleBlock() {
//        let transaction = TestData.p2pkTransaction
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.header.dataHash], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        let handled = task.handle(transaction: transaction)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleTransaction_CompletesPendingMerkleBlock_AllBlocksReceived() {
//        let transaction = TestData.p2pkTransaction
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.header.dataHash], transactions: [])
//        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        let _ = task.handle(merkleBlock: merkleBlock2)
//        resetMockDelegate()
//        dateIsGenerated = false
//
//        let handled = task.handle(transaction: transaction)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
//        verify(mockDelegate).handle(completedTask: equal(to: task))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testHandleTransaction_DoesNotCompletePendingMerkleBlock() {
//        let transaction = TestData.p2pkTransaction
//        let transaction2 = TestData.p2pkhTransaction
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.header.dataHash, transaction2.header.dataHash], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        let handled = task.handle(transaction: transaction)
//
//        XCTAssertTrue(handled)
//        XCTAssertTrue(dateIsGenerated)
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testCheckTimeout_NoPendingBlocks_allowedIdleTime_HasPassed() {
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        let _ = task.handle(merkleBlock: merkleBlock2)
//        resetMockDelegate()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000)
//        task.resetTimer()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime + 1)
//        task.checkTimeout()
//
//        verify(mockDelegate).handle(completedTask: equal(to: task))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testCheckTimeout_NoPendingBlocks_allowedIdleTime_HasNotPassed() {
//        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
//        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])
//
//        let _ = task.handle(merkleBlock: merkleBlock)
//        let _ = task.handle(merkleBlock: merkleBlock2)
//        resetMockDelegate()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000)
//        task.resetTimer()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime - 1)
//        task.checkTimeout()
//
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testCheckTimeout_PendingBlocksExist_allowedIdleTime_HasPassed() {
//        generatedDate = Date(timeIntervalSince1970: 1000000)
//        task.resetTimer()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime + 1)
//        task.checkTimeout()
//
//        verify(mockDelegate).handle(failedTask: equal(to: task), error: equal(to: PeerTask.TimeoutError(), equalWhen: { type(of: $0) == type(of: $1) }))
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    func testCheckTimeout_PendingBlocksExist_allowedIdleTime_HasNotPassed() {
//        generatedDate = Date(timeIntervalSince1970: 1000000)
//        task.resetTimer()
//
//        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime - 1)
//        task.checkTimeout()
//
//        verifyNoMoreInteractions(mockDelegate)
//    }
//
//    private func resetMockDelegate() {
//        reset(mockDelegate)
//        stub(mockDelegate) { mock in
//            when(mock).handle(merkleBlock: any()).thenDoNothing()
//            when(mock).handle(failedTask: any(), error: any()).thenDoNothing()
//            when(mock).handle(completedTask: any()).thenDoNothing()
//        }
//    }
//
//}
