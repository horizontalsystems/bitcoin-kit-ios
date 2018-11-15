import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionSyncerTests: XCTestCase {

    private var mockRealmFactory: MockIRealmFactory!
    private var mockTransactionProcessor: MockITransactionProcessor!
    private var mockAddressManager: MockIAddressManager!
    private var mockBloomFilterManager: MockIBloomFilterManager!

    private var maxRetriesCount: Int!
    private var retriesPeriod: Double!
    private var totalRetriesPeriod: Double!

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

        maxRetriesCount = 3
        retriesPeriod = 60
        totalRetriesPeriod = 60 * 60 * 24

        syncer = TransactionSyncer(
                realmFactory: mockRealmFactory, processor: mockTransactionProcessor, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                maxRetriesCount: maxRetriesCount, retriesPeriod: retriesPeriod, totalRetriesPeriod: totalRetriesPeriod)
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockTransactionProcessor = nil
        mockAddressManager = nil
        mockBloomFilterManager = nil

        maxRetriesCount = nil
        retriesPeriod = nil
        totalRetriesPeriod = nil

        realm = nil
        syncer = nil

        super.tearDown()
    }

    func testPendingTransactions() {
        let relayedTransaction = TestData.p2pkhTransaction
        let newTransaction = TestData.p2wpkhTransaction
        let newSentTransaction = TestData.p2pkTransaction
        let sentTransaction = SentTransaction(reversedHashHex: newSentTransaction.reversedHashHex)
        relayedTransaction.status = .relayed
        newTransaction.status = .new
        newSentTransaction.status = .new
        sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1

        try! realm.write {
            realm.add(relayedTransaction)
            realm.add(newTransaction)
            realm.add(newSentTransaction)
            realm.add(sentTransaction)
        }

        var transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions.first!.dataHash, newTransaction.dataHash)
        XCTAssertEqual(transactions.last!.dataHash, newSentTransaction.dataHash)

        try! realm.write {
            realm.delete(newTransaction)
            // sentTransaction retriesCount has exceeded
            sentTransaction.retriesCount = maxRetriesCount
        }

        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)

        try! realm.write {
            sentTransaction.retriesCount = 0
            // sentTransaction retriesPeriod has not elapsed
            sentTransaction.lastSendTime = CACurrentMediaTime()
        }

        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)

        try! realm.write {
            sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1
            // sentTransaction totalRetriesPeriod has elapsed
            sentTransaction.firstSendTime = CACurrentMediaTime() - totalRetriesPeriod - 1
        }

        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)
    }

    func testHandleSentTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        try! realm.write {
            realm.add(transaction)
        }

        syncer.handle(sentTransaction: transaction)

        let sentTransaction = realm.objects(SentTransaction.self).last!
        XCTAssertEqual(sentTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(sentTransaction.retriesCount, 0)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.firstSendTime), 0.1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.lastSendTime), 0.1)
    }

    func testHandleSentTransaction_SentTransactionExists() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new
        let sentTransaction = SentTransaction(reversedHashHex: transaction.reversedHashHex)
        sentTransaction.firstSendTime = sentTransaction.firstSendTime - 100
        sentTransaction.lastSendTime = sentTransaction.lastSendTime - 100

        try! realm.write {
            realm.add(transaction)
            realm.add(sentTransaction)
        }

        syncer.handle(sentTransaction: transaction)

        XCTAssertEqual(sentTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(sentTransaction.retriesCount, 1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.firstSendTime - 100), 0.1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.lastSendTime), 0.1)
    }

    func testHandleSentTransaction_transactionNotExists() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        syncer.handle(sentTransaction: transaction)

        XCTAssertEqual(realm.objects(SentTransaction.self).count, 0)
    }

    func testHandleSentTransaction_transactionIsNotNew() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .relayed

        syncer.handle(sentTransaction: transaction)

        XCTAssertEqual(realm.objects(SentTransaction.self).count, 0)
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
