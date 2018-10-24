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
            when(mock.gapShifts()).thenReturn(false)
        }

        transactionProcessor = TransactionProcessor(extractor: mockExtractor, linker: mockLinker, addressManager: mockAddressManager)
    }

    override func tearDown() {
        mockExtractor = nil
        mockLinker = nil
        transactionProcessor = nil

        realm = nil

        super.tearDown()
    }

    func testProcessSingleTransaction() {
        let transaction = TestData.p2pkhTransaction

        try! realm.write {
            realm.add(transaction)
        }

        transactionProcessor.process(transaction: transaction, realm: realm)

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
    }

    func testProcessTransactions_TransactionExists() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        try! realm.write {
            realm.add(transaction)
        }

        try! realm.write {
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
        }

        verify(mockExtractor, never()).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker, never()).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_Mine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        try! realm.write {
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_NotMine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = false

        try! realm.write {
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 0)
    }

    func testProcessTransactions_TransactionNotExists_Mine_GapShifts() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        stub(mockAddressManager) { mock in
            when(mock.gapShifts()).thenReturn(true)
        }

        try! realm.write {
            do {
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_Mine_HasUnspentOutputs() {
        let publicKey = TestData.pubKey()
        let transaction = TestData.p2wpkhTransaction
        transaction.isMine = true
        transaction.outputs[0].publicKey = publicKey

        try! realm.write {
            realm.add(publicKey)
        }

        try! realm.write {
            do {
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_Mine_GapShifts_CheckBloomFilterFalse() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        stub(mockAddressManager) { mock in
            when(mock.gapShifts()).thenReturn(true)
        }

        try! realm.write {
            do {
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: false, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_NotMine_GapShifts() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = false

        stub(mockAddressManager) { mock in
            when(mock.gapShifts()).thenReturn(true)
        }

        try! realm.write {
            do {
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, checkBloomFilter: true, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verify(mockExtractor).extract(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 0)
    }

}
