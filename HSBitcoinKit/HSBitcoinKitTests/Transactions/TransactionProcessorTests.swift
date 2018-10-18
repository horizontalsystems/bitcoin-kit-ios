import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionProcessorTests: XCTestCase {
    private var mockExtractor: MockITransactionExtractor!
    private var mockLinker: MockITransactionLinker!
    private var mockAddressManager: MockIAddressManager!
    private var transactionProcessor: TransactionProcessor!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockExtractor = MockITransactionExtractor()
        mockLinker = MockITransactionLinker()
        mockAddressManager = MockIAddressManager()

        stub(mockLinker) { mock in
            when(mock.handle(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockExtractor) { mock in
            when(mock.extract(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockAddressManager) { mock in
            when(mock.fillGap()).thenDoNothing()
        }

        transactionProcessor = TransactionProcessor(realmFactory: mockRealmFactory, extractor: mockExtractor, linker: mockLinker, addressManager: mockAddressManager, queue: DispatchQueue.main)
    }

    override func tearDown() {
        mockExtractor = nil
        mockLinker = nil
        mockAddressManager = nil
        transactionProcessor = nil

        realm = nil

        super.tearDown()
    }

    func testTransactionProcessing() {
        let transaction = TestData.p2pkhTransaction
        let processedTransaction = TestData.p2shTransaction
        processedTransaction.processed = true

        try! realm.write {
            realm.add(transaction)
            realm.add(processedTransaction)
        }

        transactionProcessor.enqueueRun()

        waitForMainQueue()

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: any())
        verify(mockExtractor, never()).extract(transaction: equal(to: processedTransaction), realm: any())

        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker, never()).handle(transaction: equal(to: processedTransaction), realm: equal(to: realm))

        verify(mockAddressManager).fillGap()

        XCTAssertEqual(transaction.processed, true)
    }

    func testNoActionWhenNoTransaction() {
        transactionProcessor.enqueueRun()

        waitForMainQueue()
        verifyNoMoreInteractions(mockExtractor)
        verifyNoMoreInteractions(mockLinker)
        verifyNoMoreInteractions(mockAddressManager)
    }

}
