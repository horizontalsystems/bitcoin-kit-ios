import XCTest
import Cuckoo
import HSCryptoKit
@testable import HSBitcoinKit

class GetMerkleBlockTaskTests:XCTestCase {

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private var blockHashes: [BlockHash]!
    private var blockHeaders: [BlockHeader]!
    private var pingNonce: UInt64!
    private var task: GetMerkleBlocksTask!

    override func setUp() {
        super.setUp()

        mockRequester = MockIPeerTaskRequester()
        mockDelegate = MockIPeerTaskDelegate()

        stub(mockRequester) { mock in
            when(mock).getData(items: any()).thenDoNothing()
            when(mock).ping(nonce: any()).thenDoNothing()
        }
        stub(mockDelegate) { mock in
            when(mock).handle(merkleBlock: any()).thenDoNothing()
            when(mock).handle(failedTask: any(), error: any()).thenDoNothing()
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        blockHeaders = [
            BlockHeader(version: 0, previousBlockHeaderReversedHex: Data(from: 100000).hex, merkleRootReversedHex: "00011122", timestamp: 0, bits: 0, nonce: 0),
            BlockHeader(version: 0, previousBlockHeaderReversedHex: Data(from: 200000).hex, merkleRootReversedHex: "00011122", timestamp: 0, bits: 0, nonce: 0)
        ]
        blockHashes = [
            BlockHash(withHeaderHash: CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: blockHeaders[0])), height: 10),
            BlockHash(withHeaderHash: CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: blockHeaders[1])), height: 15)
        ]
        pingNonce = UInt64.random(in: 0..<UINT64_MAX)

        task = GetMerkleBlocksTask(blockHashes: blockHashes, pingNonce: pingNonce)
        task.requester = mockRequester
        task.delegate = mockDelegate
    }

    override func tearDown() {
        blockHashes = nil
        pingNonce = nil
        task = nil

        super.tearDown()
    }

    func testStart() {
        task.start()

        verify(mockRequester).getData(items: equal(to: [], equalWhen: { value, given in
            return given.filter { inv in
                return self.blockHashes.contains { blockHash in
                    return blockHash.headerHash == inv.hash
                }
            }.count == given.count
        }))
        verify(mockRequester).ping(nonce: equal(to: pingNonce))
    }

    func testHandleMerkleBlock_BlockWasNotRequested() {
        let blockHeader = BlockHeader(version: 0, previousBlockHeaderReversedHex: Data(from: 300000).hex, merkleRootReversedHex: "00011122", timestamp: 0, bits: 0, nonce: 0)
        let merkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)
        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleMerkleBlock_CompleteMerkleBlock_BlockHashHasHeight() {
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)

        XCTAssertEqual(handled, true)
        XCTAssertEqual(merkleBlock.height, blockHashes[0].height)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleMerkleBlock_CompleteMerkleBlock_BlockHasHeightIsZero() {
        blockHashes[0].height = 0
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)

        XCTAssertEqual(handled, true)
        XCTAssertEqual(merkleBlock.height, nil)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleMerkleBlock_CompleteMerkleBlock_SameBlockRepeated() {
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
        verifyNoMoreInteractions(mockDelegate)

        let handled2 = task.handle(merkleBlock: merkleBlock)

        XCTAssertEqual(handled2, false)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleMerkleBlock_CompleteMerkleBlock_AllBlocksReceived() {
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)
        resetMockDelegate()

        let handled2 = task.handle(merkleBlock: merkleBlock2)

        XCTAssertEqual(handled2, true)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock2))
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleMerkleBlock_MerkleBlockWithTransactions() {
        let transaction = TestData.p2pkTransaction
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.dataHash], transactions: [])

        let handled = task.handle(merkleBlock: merkleBlock)

        XCTAssertEqual(handled, true)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_NotInPendingMerkleBlocks() {
        let transaction = TestData.p2pkTransaction
        let transaction2 = TestData.p2pkhTransaction
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.dataHash], transactions: [])

        let _ = task.handle(merkleBlock: merkleBlock)
        let handled = task.handle(transaction: transaction2)

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_CompletesPendingMerkleBlock() {
        let transaction = TestData.p2pkTransaction
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.dataHash], transactions: [])

        let _ = task.handle(merkleBlock: merkleBlock)
        let handled = task.handle(transaction: transaction)

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_CompletesPendingMerkleBlock_AllBlocksReceived() {
        let transaction = TestData.p2pkTransaction
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.dataHash], transactions: [])
        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])

        let _ = task.handle(merkleBlock: merkleBlock)
        let _ = task.handle(merkleBlock: merkleBlock2)
        resetMockDelegate()

        let handled = task.handle(transaction: transaction)

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(merkleBlock: equal(to: merkleBlock))
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_DoesNotCompletePendingMerkleBlock() {
        let transaction = TestData.p2pkTransaction
        let transaction2 = TestData.p2pkhTransaction
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [transaction.dataHash, transaction2.dataHash], transactions: [])

        let _ = task.handle(merkleBlock: merkleBlock)
        let handled = task.handle(transaction: transaction)

        XCTAssertEqual(handled, true)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testPingNonce_NoPendingBlocks() {
        let merkleBlock = MerkleBlock(header: blockHeaders[0], transactionHashes: [], transactions: [])
        let merkleBlock2 = MerkleBlock(header: blockHeaders[1], transactionHashes: [], transactions: [])

        let _ = task.handle(merkleBlock: merkleBlock)
        let _ = task.handle(merkleBlock: merkleBlock2)
        resetMockDelegate()

        let handled = task.handle(pongNonce: pingNonce)

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testPingNonce_PendingBlocksExist() {
        let handled = task.handle(pongNonce: pingNonce)

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(failedTask: equal(to: task), error: equal(to: GetMerkleBlocksTask.MerkleBlocksNotReceived(), equalWhen: { type(of: $0) == type(of: $1) }))
        verifyNoMoreInteractions(mockDelegate)
    }

    private func resetMockDelegate() {
        reset(mockDelegate)
        stub(mockDelegate) { mock in
            when(mock).handle(merkleBlock: any()).thenDoNothing()
            when(mock).handle(failedTask: any(), error: any()).thenDoNothing()
            when(mock).handle(completedTask: any()).thenDoNothing()
        }
    }

}
