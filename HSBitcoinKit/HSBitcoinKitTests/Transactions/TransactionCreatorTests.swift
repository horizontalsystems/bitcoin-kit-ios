import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionCreatorTests: XCTestCase {

    private var realm: Realm!
    private var mockTransactionBuilder: MockITransactionBuilder!
    private var mockTransactionProcessor: MockITransactionProcessor!
    private var mockPeerGroup: MockIPeerGroup!

    private var transactionCreator: TransactionCreator!
    private let transaction = TestData.p2pkhTransaction

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockTransactionBuilder = MockITransactionBuilder()
        mockTransactionProcessor = MockITransactionProcessor()
        mockPeerGroup = MockIPeerGroup()

        stub(mockTransactionBuilder) { mock in
            when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())).thenReturn(transaction)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.processOutgoing(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockPeerGroup) { mock in
            when(mock.sendPendingTransactions()).thenDoNothing()
            when(mock.checkPeersSynced()).thenDoNothing()
        }

        transactionCreator = TransactionCreator(realmFactory: mockRealmFactory, transactionBuilder: mockTransactionBuilder, transactionProcessor: mockTransactionProcessor, peerGroup: mockPeerGroup)
    }

    override func tearDown() {
        realm = nil
        mockTransactionBuilder = nil
        mockTransactionProcessor = nil
        mockPeerGroup = nil
        transactionCreator = nil

        super.tearDown()
    }

    func testCreateTransaction() {
        try! transactionCreator.create(to: "Address", value: 1, feeRate: 1, senderPay: true)

        verify(mockPeerGroup).checkPeersSynced()

        verify(mockTransactionProcessor).processOutgoing(transaction: equal(to: transaction), realm: any())
        verify(mockPeerGroup).sendPendingTransactions()
    }

    func testCreateTransaction_transactionAlreadyExists() {
        try! realm.write {
            realm.add(TestData.p2pkhTransaction)
        }

        do {
            try transactionCreator.create(to: "Address", value: 1, feeRate: 1, senderPay: true)
            XCTFail("No exception")
        } catch let error as TransactionCreator.CreationError {
            XCTAssertEqual(error, TransactionCreator.CreationError.transactionAlreadyExists)
        } catch {
            XCTFail("Unexpected exception")
        }

        verify(mockPeerGroup, never()).sendPendingTransactions()
        verify(mockTransactionProcessor, never()).processOutgoing(transaction: equal(to: transaction), realm: any())
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
        verify(mockTransactionProcessor, never()).processOutgoing(transaction: any(), realm: any())
    }

}
