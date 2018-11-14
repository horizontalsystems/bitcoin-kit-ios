import XCTest
import Cuckoo
@testable import HSBitcoinKit

class GetBlockHashesTaskTests:XCTestCase {

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private var hashes: [Data]!
    private var pingNonce: UInt64!
    private var task: GetBlockHashesTask!

    override func setUp() {
        super.setUp()

        mockRequester = MockIPeerTaskRequester()
        mockDelegate = MockIPeerTaskDelegate()

        stub(mockRequester) { mock in
            when(mock).getBlocks(hashes: any()).thenDoNothing()
            when(mock).ping(nonce: any()).thenDoNothing()
        }
        stub(mockDelegate) { mock in
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        hashes = [Data(from: 1000000)]
        pingNonce = UInt64.random(in: 0..<UINT64_MAX)
        task = GetBlockHashesTask(hashes: hashes, pingNonce: pingNonce)

        task.requester = mockRequester
        task.delegate = mockDelegate
    }

    override func tearDown() {
        hashes = nil
        pingNonce = nil
        task = nil

        super.tearDown()
    }

    func testStart() {
        task.start()

        verify(mockRequester).getBlocks(hashes: equal(to: hashes))
        verify(mockRequester).ping(nonce: equal(to: pingNonce))
    }

    func testHandleItems() {
        let blockInv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let txInv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 200000001))

        let handled = task.handle(items: [blockInv, txInv])

        XCTAssertEqual(handled, true)
        XCTAssertEqual(task.blockHashes, [blockInv.hash])
    }

    func testHandleItems_NewHashesContainLocatorHashes() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: hashes[0])

        let handled = task.handle(items: [block0Inv])

        XCTAssertEqual(handled, true)
        XCTAssertEqual(task.blockHashes, [])
    }

    func testHandleItems_NewHashesLessThanExisting() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let block1Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 300000000))
        let block2Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 400000000))

        let _ = task.handle(items: [block0Inv, block1Inv])
        let handled = task.handle(items: [block2Inv])

        XCTAssertEqual(handled, true)
        XCTAssertEqual(task.blockHashes, [block0Inv.hash, block1Inv.hash])
    }

    func testHandleItems_NewHashesMoreThanExisting() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let block1Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 300000000))
        let block2Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 400000000))

        let _ = task.handle(items: [block2Inv])
        let handled = task.handle(items: [block0Inv, block1Inv])

        XCTAssertEqual(handled, true)
        XCTAssertEqual(task.blockHashes, [block0Inv.hash, block1Inv.hash])
    }

    func testHandlePongNonce() {
        XCTAssertEqual(task.handle(pongNonce: 0), false)

        let handled = task.handle(pongNonce: pingNonce)
        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(completedTask: equal(to: task))
    }

}
