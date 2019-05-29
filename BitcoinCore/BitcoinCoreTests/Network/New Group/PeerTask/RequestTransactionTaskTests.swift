import XCTest
import Cuckoo
@testable import BitcoinCore

class RequestTransactionTaskTests: XCTestCase {

    private var mockRequester: MockIPeerTaskRequester!
    private var mockDelegate: MockIPeerTaskDelegate!

    private var transactions: [FullTransaction]!
    private var task: RequestTransactionsTask!

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

        transactions = [
            TestData.p2wpkhTransaction,
            TestData.p2pkhTransaction
        ]
        task = RequestTransactionsTask(hashes: transactions.map { $0.header.dataHash })

        task.requester = mockRequester
        task.delegate = mockDelegate
    }

    override func tearDown() {
        transactions = nil
        task = nil

        super.tearDown()
    }

    func testStart() {
        task.start()

        verify(mockRequester).send(message: equal(to: GetDataMessage(inventoryItems: []), equalWhen: { value, given in
            let givenInventories = (given as! GetDataMessage).inventoryItems
            return givenInventories.filter { inv in
                return self.transactions.contains { transaction in
                    return transaction.header.dataHash == inv.hash
                }
            }.count == givenInventories.count
        }))
        verifyNoMoreInteractions(mockRequester)
    }

    func testHandleTransaction_NotRequestedTransaction() {
        let handled = try! task.handle(message: TransactionMessage(transaction: TestData.p2pkTransaction, size: 0))

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction() {
        let handled = try! task.handle(message: TransactionMessage(transaction: transactions[0], size: 0))

        XCTAssertEqual(handled, true)
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_AllTransactionsReceived() {
        let _ = try! task.handle(message: TransactionMessage(transaction: transactions[0], size: 0))
        reset(mockDelegate)
        stub(mockDelegate) { mock in
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        let handled = try! task.handle(message: TransactionMessage(transaction: transactions[1], size: 0))

        XCTAssertEqual(handled, true)
        verify(mockDelegate).handle(completedTask: equal(to: task))
        verifyNoMoreInteractions(mockDelegate)
    }

    func testHandleTransaction_SaveTransactionRepeated() {
        let _ = try! task.handle(message: TransactionMessage(transaction: transactions[0], size: 0))
        reset(mockDelegate)
        stub(mockDelegate) { mock in
            when(mock).handle(completedTask: any()).thenDoNothing()
        }

        let handled = try! task.handle(message: TransactionMessage(transaction: transactions[0], size: 0))

        XCTAssertEqual(handled, false)
        verifyNoMoreInteractions(mockDelegate)
    }

}
