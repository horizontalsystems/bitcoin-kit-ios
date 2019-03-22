import XCTest
import Cuckoo
@testable import HSBitcoinKit

class TransactionProcessorTests: XCTestCase {
    private var mockOutputExtractor: MockITransactionExtractor!
    private var mockOutputAddressExtractor: MockITransactionOutputAddressExtractor!
    private var mockInputExtractor: MockITransactionExtractor!
    private var mockLinker: MockITransactionLinker!
    private var mockAddressManager: MockIAddressManager!
    private var mockBlockchainDataListener: MockIBlockchainDataListener!

    private var generatedDate: Date!
    private var dateGenerator: (() -> Date)!

    private var transactionProcessor: TransactionProcessor!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        generatedDate = Date()
        dateGenerator = {
            return self.generatedDate
        }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockOutputExtractor = MockITransactionExtractor()
        mockOutputAddressExtractor = MockITransactionOutputAddressExtractor()
        mockInputExtractor = MockITransactionExtractor()
        mockLinker = MockITransactionLinker()
        mockAddressManager = MockIAddressManager()
        mockBlockchainDataListener = MockIBlockchainDataListener()

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
        stub(mockBlockchainDataListener) { mock in
            when(mock.onUpdate(updated: any(), inserted: any())).thenDoNothing()
            when(mock.onDelete(transactionHashes: any())).thenDoNothing()
            when(mock.onInsert(block: any())).thenDoNothing()
        }

        transactionProcessor = TransactionProcessor(outputExtractor: mockOutputExtractor, inputExtractor: mockInputExtractor, linker: mockLinker, outputAddressExtractor: mockOutputAddressExtractor, addressManager: mockAddressManager, listener: mockBlockchainDataListener, dateGenerator: dateGenerator)
    }

    override func tearDown() {
        mockOutputExtractor = nil
        mockInputExtractor = nil
        mockLinker = nil
        transactionProcessor = nil
        mockBlockchainDataListener = nil

        generatedDate = nil
        dateGenerator = nil

        realm = nil

        super.tearDown()
    }

    func testProcessSingleTransaction() {
        let transaction = TestData.p2pkhTransaction

        try! transactionProcessor.processCreated(transaction: transaction, realm: realm)

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))
        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))

        verifyNoMoreInteractions(mockOutputAddressExtractor)
        verifyNoMoreInteractions(mockInputExtractor)
    }

    func testProcessSingleTransaction_isMine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        try! transactionProcessor.processCreated(transaction: transaction, realm: realm)

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))
        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
    }

    func testProcessTransactions_TransactionExists() {
        let transaction = TestData.p2pkhTransaction
        let incomingTransaction = TestData.p2pkhTransaction
        incomingTransaction.status = .new

        transaction.status = .new

        try! realm.write {
            realm.add(transaction)
        }

        try! realm.write {
            try! transactionProcessor.processReceived(transactions: [incomingTransaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor, never()).extract(transaction: equal(to: transaction))
        verify(mockLinker, never()).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transaction]), inserted: equal(to: []))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_SeveralMempoolTransactions() {
        let transactions = self.transactions()
        for transaction in transactions {
            transaction.isMine = true
            transaction.timestamp = 0
            transaction.order = 0
        }

        try! realm.write {
            realm.add([transactions[1], transactions[3]])
            transactions[1].status = .new
        }

        try! realm.write {
            try! transactionProcessor.processReceived(transactions: [transactions[3], transactions[1], transactions[2], transactions[0]], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        let realmTransactions = realm.objects(Transaction.self).sorted(byKeyPath: "order")

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transactions[1], transactions[3]]), inserted: equal(to: [transactions[0], transactions[2]]))

        XCTAssertEqual(realmTransactions.count, 4)
        for (i, transaction) in transactions.enumerated() {
            XCTAssertEqual(realmTransactions[i].dataHash, transaction.dataHash)
            XCTAssertEqual(realmTransactions[i].status, .relayed)
            XCTAssertEqual(realmTransactions[i].order, i)
            XCTAssertEqual(realmTransactions[i].timestamp, Int(generatedDate.timeIntervalSince1970))
        }
    }

    func testProcessTransactions_SeveralTransactionsInBlock() {
        let transactions = self.transactions()
        let block = TestData.firstBlock

        for transaction in transactions {
            transaction.isMine = true
            transaction.timestamp = 0
            transaction.order = 0
        }

        try! realm.write {
            realm.add(block)
            realm.add([transactions[1], transactions[3]])
            transactions[1].status = .new
        }

        try! realm.write {
            try! transactionProcessor.processReceived(transactions: [transactions[3], transactions[1], transactions[2], transactions[0]], inBlock: block, skipCheckBloomFilter: false, realm: realm)
        }

        let realmTransactions = realm.objects(Transaction.self).sorted(byKeyPath: "order")

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transactions[1], transactions[3]]), inserted: equal(to: [transactions[0], transactions[2]]))

        XCTAssertEqual(realmTransactions.count, 4)
        for (i, transaction) in transactions.enumerated() {
            XCTAssertEqual(realmTransactions[i].block?.headerHashReversedHex, block.headerHashReversedHex)
            XCTAssertEqual(realmTransactions[i].dataHash, transaction.dataHash)
            XCTAssertEqual(realmTransactions[i].status, .relayed)
            XCTAssertEqual(realmTransactions[i].order, i)
            XCTAssertEqual(realmTransactions[i].timestamp, block.header!.timestamp)
        }
    }

    func testProcessTransactions_TransactionNotExists_Mine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = true

        try! realm.write {
            try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))

        XCTAssertEqual(realmTransactions.count, 1)
        XCTAssertEqual(realmTransactions.first!.dataHash, transaction.dataHash)
        XCTAssertEqual(realmTransactions.first!.status, TransactionStatus.relayed)
        XCTAssertEqual(realmTransactions.first!.block, nil)
    }

    func testProcessTransactions_TransactionNotExists_NotMine() {
        let transaction = TestData.p2pkhTransaction
        transaction.isMine = false

        try! realm.write {
            try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verifyNoMoreInteractions(mockBlockchainDataListener)

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
                try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))

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
                try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
                XCTFail("Should throw exception")
            } catch _ as BloomFilterManager.BloomFilterExpired {
            } catch {
                XCTFail("Unknown error thrown")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))

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
                try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: true, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction]))

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
                try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false, realm: realm)
            } catch {
                XCTFail("Shouldn't throw exception")
            }
        }

        verifyNoMoreInteractions(mockBlockchainDataListener)

        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
        verify(mockLinker).handle(transaction: equal(to: transaction), realm: equal(to: realm))

        let realmTransactions = realm.objects(Transaction.self)
        XCTAssertEqual(realmTransactions.count, 0)
    }

    func testProcessTransactions_TransactionNotInTopologicalOrder() {
        let transactions = self.transactions()
        var calledTransactions = [Transaction]()

        stub(mockOutputExtractor) { mock in
            when(mock.extract(transaction: any())).then { transaction in
                calledTransactions.append(transaction)
            }
        }

        for i in 0..<4 {
            for j in 0..<4 {
                for k in 0..<4 {
                    for l in 0..<4 {
                        if [0, 1, 2, 3].contains(where: { $0 != i && $0 != j && $0 != k && $0 != l }) {
                            continue
                        }

                        calledTransactions = []

                        try! transactionProcessor.processReceived(transactions: [transactions[i], transactions[j], transactions[k], transactions[l]], inBlock: nil, skipCheckBloomFilter: false, realm: realm)

                        verifyNoMoreInteractions(mockBlockchainDataListener)

                        for (m, transaction) in calledTransactions.enumerated() {
                            XCTAssertEqual(transaction.dataHashReversedHex, transactions[m].dataHashReversedHex)
                        }
                    }
                }
            }
        }
    }


    private func transactions() -> [Transaction] {
        let transaction = Transaction(
                version: 0,
                inputs: [
                    Input(
                            withPreviousOutputTxReversedHex: Data(from: 1).hex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        let transaction2 = Transaction(
                version: 0,
                inputs: [
                    Input(
                            withPreviousOutputTxReversedHex: transaction.dataHashReversedHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
                    Output(withValue: 0, index: 1, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        let transaction3 = Transaction(
                version: 0,
                inputs: [
                    Input(
                            withPreviousOutputTxReversedHex: transaction2.dataHashReversedHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
                ],
                lockTime: 0
        )

        let transaction4 = Transaction(
                version: 0,
                inputs: [
                    Input(
                            withPreviousOutputTxReversedHex: transaction2.dataHashReversedHex,
                            previousOutputIndex: 1,
                            script: Data(from: 999999999999),
                            sequence: 0
                    ),
                    Input(
                            withPreviousOutputTxReversedHex: transaction3.dataHashReversedHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        return [transaction, transaction2, transaction3, transaction4]
    }

}
