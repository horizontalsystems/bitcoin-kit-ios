import XCTest
import Cuckoo
@testable import BitcoinCore

class SendTransactionTaskTests:XCTestCase {

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private var transaction: FullTransaction!
    private var task: SendTransactionTask!

    override func setUp() {
        super.setUp()

        mockRequester = MockIPeerTaskRequester()
        mockDelegate = MockIPeerTaskDelegate()

        stub(mockRequester) { mock in
            when(mock).send(message: any()).thenDoNothing()
        }
        stub(mockDelegate) { mock in
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        transaction = TestData.p2wpkhTransaction
        task = SendTransactionTask(transaction: transaction)

        task.requester = mockRequester
        task.delegate = mockDelegate
    }

    override func tearDown() {
        transaction = nil
        task = nil

        super.tearDown()
    }

    func testStart() {
        task.start()
        let message = InventoryMessage(inventoryItems: [
            InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.header.dataHash)
        ])

        verify(mockRequester).send(message: equal(to: message, equalWhen: { ($0 as! InventoryMessage).inventoryItems.first!.hash == ($1 as! InventoryMessage).inventoryItems.first!.hash }))
    }

    func testHandleGetData() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.header.dataHash)

        let handled = try! task.handle(message: GetDataMessage(inventoryItems: [inv]))

        XCTAssertEqual(handled, true)
        verify(mockRequester).send(message: equal(to: TransactionMessage(transaction: transaction, size: 0), equalWhen: { ($0 as! TransactionMessage).transaction.header.dataHash == ($1 as! TransactionMessage).transaction.header.dataHash }))
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleGetData_NotTransactionInventory() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: transaction.header.dataHash)

        let handled = try! task.handle(message: GetDataMessage(inventoryItems: [inv]))

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleGetData_OtherTransactionInventory() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 10000))

        let handled = try! task.handle(message: GetDataMessage(inventoryItems: [inv]))

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

}
