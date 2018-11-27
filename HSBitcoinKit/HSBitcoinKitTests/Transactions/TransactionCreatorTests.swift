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
            when(mock.buildTransaction(value: any(), feeRate: any(), senderPay: any(), toAddress: any())).thenReturn(TestData.p2pkhTransaction)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockPeerGroup) { mock in
            when(mock.sendPendingTransactions()).thenDoNothing()
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

        guard let transaction = realm.objects(Transaction.self).filter("reversedHashHex = %@", TestData.p2pkhTransaction.reversedHashHex).first else {
            XCTFail("No transaction record!")
            return
        }

        verify(mockPeerGroup).sendPendingTransactions()
        verify(mockTransactionProcessor).process(transaction: equal(to: transaction), realm: any())
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
        verify(mockTransactionProcessor, never()).process(transaction: any(), realm: any())
    }

}
