import XCTest
import Quick
import Nimble
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionSyncerTests: XCTestCase {

    private var mockStorage: MockIStorage!
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

        mockStorage = MockIStorage()
        mockTransactionProcessor = MockITransactionProcessor()
        mockAddressManager = MockIAddressManager()
        mockBloomFilterManager = MockIBloomFilterManager()

        stub(mockStorage) { mock in
            when(mock.inTransaction(_: any())).then({ try? $0(self.realm) })
        }
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
                storage: mockStorage, processor: mockTransactionProcessor, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                maxRetriesCount: maxRetriesCount, retriesPeriod: retriesPeriod, totalRetriesPeriod: totalRetriesPeriod)
    }

    override func tearDown() {
        mockStorage = nil
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
        let newTransaction = TestData.p2wpkhTransaction
        let newSentTransaction = TestData.p2pkTransaction
        let sentTransaction = SentTransaction(reversedHashHex: newSentTransaction.reversedHashHex)
        sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1

        stub(mockStorage) { mock in
            when(mock.newTransactions()).thenReturn([newTransaction, newSentTransaction])
            when(mock.sentTransaction(byReversedHashHex: newTransaction.reversedHashHex)).thenReturn(nil)
            when(mock.sentTransaction(byReversedHashHex: newSentTransaction.reversedHashHex)).thenReturn(sentTransaction)
        }

        var transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions.first!.dataHash, newTransaction.dataHash)
        XCTAssertEqual(transactions.last!.dataHash, newSentTransaction.dataHash)

        stub(mockStorage) { mock in
            when(mock.newTransactions()).thenReturn([newSentTransaction])
        }
        sentTransaction.retriesCount = maxRetriesCount
        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)

        sentTransaction.retriesCount = 0
        sentTransaction.lastSendTime = CACurrentMediaTime()
        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)

        sentTransaction.lastSendTime = CACurrentMediaTime() - retriesPeriod - 1
        sentTransaction.firstSendTime = CACurrentMediaTime() - totalRetriesPeriod - 1
        transactions = syncer.pendingTransactions()
        XCTAssertEqual(transactions.count, 0)
    }

    func testHandleSentTransaction() {
        let transaction = TestData.p2pkhTransaction

        stub(mockStorage) { mock in
            when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(transaction)
            when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(nil)
            when(mock.add(sentTransaction: any(), realm: equal(to: realm))).thenDoNothing()
        }

        syncer.handle(sentTransaction: transaction)

        let argumentCaptor = ArgumentCaptor<SentTransaction>()
        verify(mockStorage).add(sentTransaction: argumentCaptor.capture(), realm: equal(to: realm))
        let sentTransaction = argumentCaptor.value!

        XCTAssertEqual(sentTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(sentTransaction.retriesCount, 0)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.firstSendTime), 0.1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.lastSendTime), 0.1)
    }

    func testHandleSentTransaction_SentTransactionExists() {
        let transaction = TestData.p2pkhTransaction
        var sentTransaction = SentTransaction(reversedHashHex: transaction.reversedHashHex)
        sentTransaction.firstSendTime = sentTransaction.firstSendTime - 100
        sentTransaction.lastSendTime = sentTransaction.lastSendTime - 100

        stub(mockStorage) { mock in
            when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(transaction)
            when(mock.sentTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(sentTransaction)
            when(mock.update(sentTransaction: any())).thenDoNothing()
        }

        syncer.handle(sentTransaction: transaction)

        let argumentCaptor = ArgumentCaptor<SentTransaction>()
        verify(mockStorage).update(sentTransaction: argumentCaptor.capture())
        sentTransaction = argumentCaptor.value!

        XCTAssertEqual(sentTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(sentTransaction.retriesCount, 1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.firstSendTime - 100), 0.1)
        XCTAssertLessThanOrEqual(abs(CACurrentMediaTime() - sentTransaction.lastSendTime), 0.1)
    }

    func testHandleSentTransaction_transactionNotExists() {
        let transaction = TestData.p2pkhTransaction

        stub(mockStorage) { mock in
            when(mock.newTransaction(byReversedHashHex: transaction.reversedHashHex)).thenReturn(nil)
        }

        syncer.handle(sentTransaction: transaction)

        verify(mockStorage, never()).add(sentTransaction: any(), realm: any())
        verify(mockStorage, never()).update(sentTransaction: any())
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

        stub(mockStorage) { mock in
            when(mock.relayedTransactionExists(byReversedHashHex: transaction.reversedHashHex)).thenReturn(true)
        }

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), false)
    }

    func testShouldRequestTransaction_TransactionNotExists() {
        let transaction = TestData.p2wpkhTransaction

        stub(mockStorage) { mock in
            when(mock.relayedTransactionExists(byReversedHashHex: transaction.reversedHashHex)).thenReturn(false)
        }

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), true)
    }

}
