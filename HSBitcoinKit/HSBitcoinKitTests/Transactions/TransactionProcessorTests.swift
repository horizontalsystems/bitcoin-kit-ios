import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionProcessorTests: XCTestCase {
    private var mockExtractor: MockITransactionExtractor!
    private var mockLinker: MockITransactionLinker!
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

        stub(mockLinker) { mock in
            when(mock.handle(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockExtractor) { mock in
            when(mock.extract(transaction: any(), realm: any())).thenDoNothing()
        }

        transactionProcessor = TransactionProcessor(extractor: mockExtractor, linker: mockLinker)
    }

    override func tearDown() {
        mockExtractor = nil
        mockLinker = nil
        transactionProcessor = nil

        realm = nil

        super.tearDown()
    }

    func testTransactionProcessing() {
        let transaction = TestData.p2pkhTransaction

        try! realm.write {
            realm.add(transaction)
        }

        transactionProcessor.process(transaction: transaction, realm: realm)

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
    }

}
