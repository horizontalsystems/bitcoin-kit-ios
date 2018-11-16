import XCTest
import Cuckoo
@testable import HSBitcoinKit

class SendTransactionTaskTests:XCTestCase {

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private var transaction: Transaction!
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

        verify(mockRequester).sendTransactionInventory(hash: equal(to: transaction.dataHash))
    }

    func testHandleGetData() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.transaction.rawValue, hash: transaction.dataHash)

        let handled = task.handle(getDataInventoryItem: inv)

        XCTAssertEqual(handled, true)
        verify(mockRequester).send(transaction: equal(to: transaction, equalWhen: { $0.dataHash == $1.dataHash }))
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockRequester)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleGetData_NotTransactionInventory() {
        let inv = InventoryItem(type: InventoryItem.ObjectType.blockMessage.rawValue, hash: transaction.dataHash)

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
