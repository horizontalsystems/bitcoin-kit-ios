import XCTest
import Cuckoo
@testable import BitcoinCore

class GetBlockHashesTaskTests:XCTestCase {

    private var generatedDate: Date!
    private var dateIsGenerated: Bool!
    private var dateGenerator: (() -> Date)!

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private let maxAllowedIdleTime = 10.0
    private let minAllowedIdleTime = 1.0
    private let maxExpectedBlockHashesCount: Int32 = 500
    private let minExpectedBlockHashesCount: Int32 = 6

    private var hashes: [Data]!
    private var expectedHashesMinCount: Int32!
    private var allowedIdleTime: Double!

    private var task: GetBlockHashesTask!

    override func setUp() {
        super.setUp()

        dateIsGenerated = false
        generatedDate = Date()
        dateGenerator = {
            self.dateIsGenerated = true
            return self.generatedDate
        }
        mockRequester = MockIPeerTaskRequester()
        mockDelegate = MockIPeerTaskDelegate()

        stub(mockRequester) { mock in
            when(mock.protocolVersion.get).thenReturn(0)
            when(mock).send(message: any()).thenDoNothing()
        }
        stub(mockDelegate) { mock in
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        hashes = [Data(from: 1000000)]
        expectedHashesMinCount = 10
        allowedIdleTime = 1.0
        task = GetBlockHashesTask(hashes: hashes, expectedHashesMinCount: expectedHashesMinCount, dateGenerator: dateGenerator)

        task.requester = mockRequester
        task.delegate = mockDelegate
    }

    override func tearDown() {
        generatedDate = nil
        dateIsGenerated = nil
        dateGenerator = nil
        hashes = nil
        expectedHashesMinCount = nil
        allowedIdleTime = nil
        task = nil

        super.tearDown()
    }

    func testInit_GivenExpectedHashesMinCountIsLessThanMinValue() {
        // Expect at least expectedHashesMinCount items
        task = GetBlockHashesTask(hashes: [], expectedHashesMinCount: 0)
        task.delegate = mockDelegate

        var inventories = [InventoryItem]()
        for i in 0..<(minExpectedBlockHashesCount - 1) {
            inventories.append(InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 100000000 * (i+1))))
        }

        let _ = try! task.handle(message: InventoryMessage(inventoryItems: inventories))
        verifyNoMoreInteractions(mockDelegate)


        // Wait minAllowedIdleTime before timeout
        task = GetBlockHashesTask(hashes: [], expectedHashesMinCount: 0, dateGenerator: dateGenerator)
        task.delegate = mockDelegate

        generatedDate = Date(timeIntervalSince1970: 1000000)
        task.resetTimer()

        generatedDate = Date(timeIntervalSince1970: 1000000 + minAllowedIdleTime + 1)
        task.checkTimeout()

        verify(mockDelegate).handle(completedTask: equal(to: task))
    }

    func testInit_GivenExpectedHashesMinCountIsMoreThanMaxValue() {
        // Expect at least maxExpectedBlockHashesCount items
        task = GetBlockHashesTask(hashes: [], expectedHashesMinCount: maxExpectedBlockHashesCount + 100)
        task.delegate = mockDelegate

        var inventories = [InventoryItem]()
        for i in 0..<maxExpectedBlockHashesCount {
            inventories.append(InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 1000000 * (i+1))))
        }

        let _ = try! task.handle(message: InventoryMessage(inventoryItems: inventories))
        verify(mockDelegate).handle(completedTask: equal(to: task))

        // Wait maxAllowedIdleTime before timeout
        task = GetBlockHashesTask(hashes: [], expectedHashesMinCount: maxExpectedBlockHashesCount + 100, dateGenerator: dateGenerator)
        task.delegate = mockDelegate

        generatedDate = Date(timeIntervalSince1970: 1000000)
        task.resetTimer()

        generatedDate = Date(timeIntervalSince1970: 1000000 + maxAllowedIdleTime - 1)
        task.checkTimeout()

        verifyNoMoreInteractions(mockDelegate)
    }

    func testStart() {
        task.start()

        verify(mockRequester).send(message: equal(to: GetBlocksMessage(protocolVersion: 0, headerHashes: hashes), equalWhen: {
            ($0 as! GetBlocksMessage).blockLocatorHashes == ($1 as! GetBlocksMessage).blockLocatorHashes
        }))
        XCTAssertTrue(dateIsGenerated)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems() {
        let blockInv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let txInv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 200000001))

        let handled = try! task.handle(message: InventoryMessage(inventoryItems: [blockInv, txInv]))

        XCTAssertTrue(handled)
        XCTAssertTrue(dateIsGenerated)
        XCTAssertEqual(task.blockHashes, [blockInv.hash])
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems_NoBlockInventories() {
        let txInv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: Data(from: 200000001))

        let handled = try! task.handle(message: InventoryMessage(inventoryItems: [txInv]))

        XCTAssertFalse(handled)
        XCTAssertFalse(dateIsGenerated)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems_NewHashesContainLocatorHashes() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: hashes[0])

        let handled = try! task.handle(message: InventoryMessage(inventoryItems: [block0Inv]))

        XCTAssertTrue(handled)
        XCTAssertTrue(dateIsGenerated)
        XCTAssertEqual(task.blockHashes, [])
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems_NewHashesLessThanExisting() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let block1Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 300000000))
        let block2Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 400000000))

        let _ = try! task.handle(message: InventoryMessage(inventoryItems: [block0Inv, block1Inv]))
        let handled = try! task.handle(message: InventoryMessage(inventoryItems: [block2Inv]))

        XCTAssertTrue(handled)
        XCTAssertTrue(dateIsGenerated)
        XCTAssertEqual(task.blockHashes, [block0Inv.hash, block1Inv.hash])
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems_NewHashesMoreThanExisting() {
        let block0Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 200000000))
        let block1Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 300000000))
        let block2Inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 400000000))

        let _ = try! task.handle(message: InventoryMessage(inventoryItems: [block2Inv]))
        let handled = try! task.handle(message: InventoryMessage(inventoryItems: [block0Inv, block1Inv]))

        XCTAssertTrue(handled)
        XCTAssertTrue(dateIsGenerated)
        XCTAssertEqual(task.blockHashes, [block0Inv.hash, block1Inv.hash])
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleItems_NewHashesEqualToExpectedBlockHashesCount() {
        var inventories = [InventoryItem]()

        for i in 0..<expectedHashesMinCount {
            inventories.append(InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 100000000 * (i+1))))
        }

        let handled = try! task.handle(message: InventoryMessage(inventoryItems: inventories))

        XCTAssertTrue(handled)
        XCTAssertTrue(dateIsGenerated)
        XCTAssertEqual(task.blockHashes, inventories.map{ $0.hash })
        verify(mockDelegate).handle(completedTask: equal(to: task))
    }

    func testCheckTimeout_allowedIdleTime_HasPassed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        task.resetTimer()

        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime + 1)
        task.checkTimeout()

        verify(mockDelegate).handle(completedTask: equal(to: task))
    }

    func testCheckTimeout_allowedIdleTime_HasNotPassed() {
        generatedDate = Date(timeIntervalSince1970: 1000000)
        task.resetTimer()

        generatedDate = Date(timeIntervalSince1970: 1000000 + allowedIdleTime - 1)
        task.checkTimeout()

        verifyNoMoreInteractions(mockDelegate)
    }

}
