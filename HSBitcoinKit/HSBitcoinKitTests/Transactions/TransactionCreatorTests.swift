import XCTest
import Cuckoo
@testable import HSBitcoinKit

class TransactionCreatorTests: XCTestCase {

    private var mockTransactionBuilder: MockITransactionBuilder!
    private var mockTransactionProcessor: MockITransactionProcessor!
    private var mockPeerGroup: MockIPeerGroup!

    private var transactionCreator: TransactionCreator!
    private let transaction = TestData.p2pkhTransaction

    override func setUp() {
        super.setUp()

        mockTransactionBuilder = MockITransactionBuilder()
        mockTransactionProcessor = MockITransactionProcessor()
        mockPeerGroup = MockIPeerGroup()

        stub(mockTransactionBuilder) { mock in
            when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())).thenReturn(transaction)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.processCreated(transaction: any())).thenDoNothing()
        }
        stub(mockPeerGroup) { mock in
            when(mock.sendPendingTransactions()).thenDoNothing()
            when(mock.checkPeersSynced()).thenDoNothing()
        }

        transactionCreator = TransactionCreator(transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup)
    }

    override func tearDown() {
        mockTransactionBuilder = nil
        mockTransactionProcessor = nil
        mockPeerGroup = nil
        transactionCreator = nil

        super.tearDown()
    }

    func testCreateTransaction() {
        try! transactionCreator.create(to: "Address", value: 1, feeRate: 1, senderPay: true)

        verify(mockPeerGroup).checkPeersSynced()

        verify(mockTransactionProcessor).processCreated(transaction: equal(to: transaction))
        verify(mockPeerGroup).sendPendingTransactions()
    }

    func testCreateTransaction_peersNotSynced() {
        stub(mockPeerGroup) { mock in
            when(mock.checkPeersSynced()).thenThrow(PeerGroup.PeerGroupError.noConnectedPeers)
        }

        do {
            try transactionCreator.create(to: "Address", value: 1, feeRate: 1, senderPay: true)
            XCTFail("No exception")
        } catch let error as PeerGroup.PeerGroupError {
            XCTAssertEqual(error, PeerGroup.PeerGroupError.noConnectedPeers)
        } catch {
            XCTFail("Unexpected exception")
        }

        verify(mockTransactionBuilder, never()).buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())
        verify(mockPeerGroup, never()).sendPendingTransactions()
        verify(mockTransactionProcessor, never()).processCreated(transaction: any())
    }

}
