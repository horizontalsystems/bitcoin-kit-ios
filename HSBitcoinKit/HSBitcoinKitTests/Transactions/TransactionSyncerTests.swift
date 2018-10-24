import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionSyncerTests: XCTestCase {

    private var mockProcessor: MockITransactionProcessor!
    private var syncer: TransactionSyncer!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockProcessor = MockITransactionProcessor()

        stub(mockProcessor) { mock in
            when(mock.process(transaction: any(), realm: any())).thenDoNothing()
        }

        syncer = TransactionSyncer(realmFactory: mockRealmFactory, processor: mockProcessor, queue: DispatchQueue.main)
    }

    override func tearDown() {
        mockProcessor = nil
        syncer = nil
        realm = nil

        super.tearDown()
    }

//    func testHandle() {
//        let transaction = TestData.p2pkhTransaction
//
//        syncer.handle(transactions: [transaction])
//
//        waitForMainQueue()
//
//        let realmTransaction = realm.objects(Transaction.self).last!
//        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
//        XCTAssertEqual(realmTransaction.block, nil)
//
//        verify(mockProcessor).process(transaction: any(), realm: any())
//    }

    func testHandle_EmptyTransactions() {
        syncer.handle(transactions: [])

        waitForMainQueue()

        verify(mockProcessor, never()).process(transaction: any(), realm: any())
    }

    func testHandle_ExistingTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        try! realm.write {
            realm.add(transaction, update: true)
        }

        syncer.handle(transactions: [transaction])

        waitForMainQueue()

        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).process(transaction: any(), realm: any())
    }

    private func assertTransactionEqual(tx1: Transaction, tx2: Transaction) {
        XCTAssertEqual(tx1, tx2)
        XCTAssertEqual(tx1.reversedHashHex, tx2.reversedHashHex)
        XCTAssertEqual(tx1.version, tx2.version)
        XCTAssertEqual(tx1.lockTime, tx2.lockTime)
        XCTAssertEqual(tx1.inputs.count, tx2.inputs.count)
        XCTAssertEqual(tx1.outputs.count, tx2.outputs.count)

        for i in 0..<tx1.inputs.count {
            XCTAssertEqual(tx1.inputs[i].previousOutputTxReversedHex, tx2.inputs[i].previousOutputTxReversedHex)
            XCTAssertEqual(tx1.inputs[i].previousOutputIndex, tx2.inputs[i].previousOutputIndex)
            XCTAssertEqual(tx1.inputs[i].signatureScript, tx2.inputs[i].signatureScript)
            XCTAssertEqual(tx1.inputs[i].sequence, tx2.inputs[i].sequence)
        }

        for i in 0..<tx2.outputs.count {
            assertOutputEqual(out1: tx1.outputs[i], out2: tx2.outputs[i])
        }
    }

    private func assertOutputEqual(out1: TransactionOutput, out2: TransactionOutput) {
        XCTAssertEqual(out1.value, out2.value)
        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
        XCTAssertEqual(out1.index, out2.index)
    }

}
