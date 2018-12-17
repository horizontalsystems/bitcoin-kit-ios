import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionProcessorTests: XCTestCase {
    private var mockOutputExtractor: MockITransactionExtractor!
    private var mockOutputAddressExtractor: MockITransactionOutputAddressExtractor!
    private var mockPublicKeySetter: MockITransactionPublicKeySetter!
    private var mockInputExtractor: MockITransactionExtractor!
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

        mockOutputExtractor = MockITransactionExtractor()
        mockOutputAddressExtractor = MockITransactionOutputAddressExtractor()
        mockPublicKeySetter = MockITransactionPublicKeySetter()
        mockInputExtractor = MockITransactionExtractor()
        mockLinker = MockITransactionLinker()
        mockAddressManager = MockIAddressManager()

        stub(mockLinker) { mock in
            when(mock.handle(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockOutputExtractor) { mock in
            when(mock.extract(transaction: any())).thenDoNothing()
        }
        stub(mockOutputAddressExtractor) { mock in
            when(mock.extractOutputAddresses(transaction: any())).thenDoNothing()
        }
        stub(mockInputExtractor) { mock in
            when(mock.extract(transaction: any())).thenDoNothing()
        }
        stub(mockAddressManager) { mock in
            when(mock.gapShifts()).thenReturn(false)
        }
        stub(mockPublicKeySetter) { mock in
            when(mock.set(transaction: any(), realm: any())).thenDoNothing()
        }

        transactionProcessor = TransactionProcessor(outputExtractor: mockOutputExtractor, inputExtractor: mockInputExtractor, linker: mockLinker, outputAddressExtractor: mockOutputAddressExtractor, transactionPublicKeySetter: mockPublicKeySetter, addressManager: mockAddressManager)
    }

    override func tearDown() {
        mockOutputExtractor = nil
        mockInputExtractor = nil
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

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockPublicKeySetter).set(transaction: equal(to: transaction), realm: equal(to: realm))

        verifyNoMoreInteractions(mockOutputAddressExtractor)
        verifyNoMoreInteractions(mockInputExtractor)
    }

    func testProcessSingleTransaction_isMine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        try! realm.write {
            realm.add(transaction)
        }

        transactionProcessor.process(transaction: transaction, realm: realm)

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockPublicKeySetter).set(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
    }

    func testProcessTransactions_TransactionExists() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        try! realm.write {
            realm.add(transaction)
        }

        try! realm.write {
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor, never()).extract(transaction: equal(to: transaction))
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
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
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
            try! transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
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
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
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
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
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
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: true, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
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
                try transactionProcessor.process(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 0)
    }

}
