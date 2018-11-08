import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionSyncerTests: XCTestCase {

    private var mockRealmFactory: MockIRealmFactory!
    private var mockTransactionProcessor: MockITransactionProcessor!
    private var mockAddressManager: MockIAddressManager!
    private var mockBloomFilterManager: MockIBloomFilterManager!

    private var realm: Realm!
    private var syncer: TransactionSyncer!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write {
            realm.deleteAll()
        }

        mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockTransactionProcessor = MockITransactionProcessor()
        mockAddressManager = MockIAddressManager()
        mockBloomFilterManager = MockIBloomFilterManager()

        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: any(), inBlock: any(), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
        }
        stub(mockAddressManager) { mock in
            when(mock.fillGap()).thenDoNothing()
        }
        stub(mockBloomFilterManager) { mock in
            when(mock.regenerateBloomFilter()).thenDoNothing()
        }

        syncer = TransactionSyncer(realmFactory: mockRealmFactory, processor: mockTransactionProcessor, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager)
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockTransactionProcessor = nil
        mockAddressManager = nil
        mockBloomFilterManager = nil

        realm = nil
        syncer = nil

        super.tearDown()
    }

    func testNonSentTransactions() {
        let relayedTransaction = TestData.p2pkhTransaction
        let newTransaction = TestData.p2wpkhTransaction
        relayedTransaction.status = .relayed
        newTransaction.status = .new

        try! realm.write {
            realm.add(relayedTransaction)
            realm.add(newTransaction)
        }

        let transactions = syncer.getNonSentTransactions()
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first!.dataHash, newTransaction.dataHash)
    }

    func testHandle_emptyTransactions() {
        syncer.handle(transactions: [])

        verify(mockTransactionProcessor, never()).process(transactions: any(), inBlock: any(), skipCheckBloomFilter: any(), realm: any())
        verify(mockAddressManager, never()).fillGap()
        verify(mockBloomFilterManager, never()).regenerateBloomFilter()
    }

    func testHandle_NeedToUpdateBloomFilter() {
        let transactions = [TestData.p2pkhTransaction]

        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: any(), realm: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
        }

        syncer.handle(transactions: transactions)
        verify(mockTransactionProcessor).process(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false), realm: any())
        verify(mockAddressManager).fillGap()
        verify(mockBloomFilterManager).regenerateBloomFilter()
    }

    func testHandle_NotNeedToUpdateBloomFilter() {
        let transactions = [TestData.p2pkhTransaction]

        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: transactions), inBlock: any(), skipCheckBloomFilter: equal(to: false), realm: any())).thenDoNothing()
        }

        syncer.handle(transactions: transactions)
        verify(mockTransactionProcessor).process(transactions: equal(to: transactions), inBlock: equal(to: nil), skipCheckBloomFilter: equal(to: false), realm: any())
        verify(mockAddressManager, never()).fillGap()
        verify(mockBloomFilterManager, never()).regenerateBloomFilter()
    }

    func testShouldRequestTransaction_TransactionExists() {
        let transaction = TestData.p2wpkhTransaction

        try! realm.write {
            realm.add(transaction)
        }

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), false)
    }

    func testShouldRequestTransaction_TransactionNotExists() {
        let transaction = TestData.p2wpkhTransaction

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), true)
    }

}
