import XCTest
import Cuckoo
@testable import HSBitcoinKit

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
            when(mock).sendTransactionInventory(hash: any()).thenDoNothing()
            when(mock).send(transaction: any()).thenDoNothing()
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

        verify(mockRequester).sendTransactionInventory(hash: equal(to: transaction.header.dataHash))
    }

    func testHandleGetData() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.header.dataHash)

        let handled = task.handle(getDataInventoryItem: inv)

        XCTAssertEqual(handled, true)
        verify(mockRequester).send(transaction: equal(to: transaction, equalWhen: { $0.header.dataHash == $1.header.dataHash }))
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleGetData_NotTransactionInventory() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: transaction.header.dataHash)

        let handled = task.handle(getDataInventoryItem: inv)

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleGetData_OtherTransactionInventory() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: Data(from: 10000))

        let handled = task.handle(getDataInventoryItem: inv)

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

}
