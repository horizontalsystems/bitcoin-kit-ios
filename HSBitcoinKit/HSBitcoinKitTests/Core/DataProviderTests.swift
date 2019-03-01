import XCTest
import Cuckoo
import RealmSwift
import RxSwift
@testable import HSBitcoinKit

class DataProviderTests: XCTestCase {
    private var mockStorage: MockIStorage!
    private var mockAddressManager: MockIAddressManager!
    private var mockAddressConverter: MockIAddressConverter!
    private var mockPaymentAddressParser: MockIPaymentAddressParser!
    private var mockUnspentOutputProvider: MockIUnspentOutputProvider!
    private var mockTransactionCreator: MockITransactionCreator!
    private var mockTransactionBuilder: MockITransactionBuilder!
    private var mockNetwork: MockINetwork!
    private var mockDataProviderDelegate: MockIDataProviderDelegate!

    private var dataProvider: DataProvider!
    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write {
            realm.deleteAll()
        }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockStorage = MockIStorage()
        mockAddressManager = MockIAddressManager()
        mockAddressConverter = MockIAddressConverter()
        mockPaymentAddressParser = MockIPaymentAddressParser()
        mockUnspentOutputProvider = MockIUnspentOutputProvider()
        mockTransactionCreator = MockITransactionCreator()
        mockTransactionBuilder = MockITransactionBuilder()
        mockNetwork = MockINetwork()
        mockDataProviderDelegate = MockIDataProviderDelegate()

        stub(mockUnspentOutputProvider) { mock in
            when(mock.balance.get).thenReturn(0)
        }

        stub(mockDataProviderDelegate) { mock in
            when(mock.transactionsUpdated(inserted: any(), updated: any())).thenDoNothing()
            when(mock.balanceUpdated(balance: any())).thenDoNothing()
            when(mock.lastBlockInfoUpdated(lastBlockInfo: any())).thenDoNothing()
        }

        dataProvider = DataProvider(
                realmFactory: mockRealmFactory, storage: mockStorage, addressManager: mockAddressManager, addressConverter: mockAddressConverter,
                paymentAddressParser: mockPaymentAddressParser, unspentOutputProvider: mockUnspentOutputProvider,
                transactionCreator: mockTransactionCreator, transactionBuilder: mockTransactionBuilder, network: mockNetwork, debounceTime: 0
        )
        dataProvider.delegate = mockDataProviderDelegate
    }

    override func tearDown() {
        mockStorage = nil
        mockAddressManager = nil
        mockAddressConverter = nil
        mockPaymentAddressParser = nil
        mockUnspentOutputProvider = nil
        mockTransactionCreator = nil
        mockTransactionBuilder = nil
        mockNetwork = nil
        mockDataProviderDelegate = nil

        dataProvider = nil

        realm = nil

        super.tearDown()
    }

    func testTransactions() {
        let disposeBag = DisposeBag()
        let transactions = self.transactions()
        transactions[0].timestamp = 1000005
        transactions[3].timestamp = 1000002
        transactions[1].timestamp = 1000001
        transactions[2].timestamp = 1000000

        try! realm.write {
            realm.add(transactions)
        }

        var results = [TransactionInfo]()
        dataProvider.transactions(fromHash: nil, limit: 3).subscribe(
                onSuccess: { transactionInfos in
                    results = transactionInfos
                }
        ).disposed(by: disposeBag)
        waitForMainQueue()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].transactionHash, transactions[0].reversedHashHex)
        XCTAssertEqual(results[1].transactionHash, transactions[3].reversedHashHex)
        XCTAssertEqual(results[2].transactionHash, transactions[1].reversedHashHex)
    }

    func testTransactions_WithEqualTimestamps() {
        let disposeBag = DisposeBag()
        let transactions = self.transactions()
        transactions[2].timestamp = 1000005
        transactions[0].timestamp = 1000005
        transactions[3].timestamp = 1000001
        transactions[1].timestamp = 1000001

        transactions[2].order = 1
        transactions[0].order = 0
        transactions[3].order = 1
        transactions[1].order = 0


        try! realm.write {
            realm.add(transactions)
        }

        var results = [TransactionInfo]()
        dataProvider.transactions(fromHash: nil, limit: 3).subscribe(
                onSuccess: { transactionInfos in
                    results = transactionInfos
                }
        ).disposed(by: disposeBag)
        waitForMainQueue()

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].transactionHash, transactions[2].reversedHashHex)
        XCTAssertEqual(results[1].transactionHash, transactions[0].reversedHashHex)
        XCTAssertEqual(results[2].transactionHash, transactions[3].reversedHashHex)
    }

    func testTransactions_FromHashGiven() {
        let disposeBag = DisposeBag()
        let transactions = self.transactions()
        transactions[2].timestamp = 1000005
        transactions[0].timestamp = 1000005
        transactions[3].timestamp = 1000001
        transactions[1].timestamp = 1000001

        transactions[2].order = 1
        transactions[0].order = 0
        transactions[3].order = 1
        transactions[1].order = 0


        try! realm.write {
            realm.add(transactions)
        }

        // Sort by timestamps
        var results = [TransactionInfo]()
        dataProvider.transactions(fromHash: transactions[0].reversedHashHex, limit: 3).subscribe(
                onSuccess: { transactionInfos in
                    results = transactionInfos
                }
        ).disposed(by: disposeBag)
        waitForMainQueue()

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].transactionHash, transactions[3].reversedHashHex)
        XCTAssertEqual(results[1].transactionHash, transactions[1].reversedHashHex)

        // Sort by timestamps and order
        dataProvider.transactions(fromHash: transactions[3].reversedHashHex, limit: 3).subscribe(
                onSuccess: { transactionInfos in
                    results = transactionInfos
                }
        ).disposed(by: disposeBag)
        waitForMainQueue()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].transactionHash, transactions[1].reversedHashHex)
    }

    func testTransactions_LimitNotGiven() {
        let disposeBag = DisposeBag()
        let transactions = self.transactions()
        transactions[2].timestamp = 1000005
        transactions[0].timestamp = 1000005
        transactions[3].timestamp = 1000001
        transactions[1].timestamp = 1000001

        transactions[2].order = 1
        transactions[0].order = 0
        transactions[3].order = 1
        transactions[1].order = 0


        try! realm.write {
            realm.add(transactions)
        }

        // Sort by timestamps
        var results = [TransactionInfo]()
        dataProvider.transactions(fromHash: nil, limit: nil).subscribe(
                onSuccess: { transactionInfos in
                    results = transactionInfos
                }
        ).disposed(by: disposeBag)
        waitForMainQueue()

        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results[0].transactionHash, transactions[2].reversedHashHex)
        XCTAssertEqual(results[1].transactionHash, transactions[0].reversedHashHex)
        XCTAssertEqual(results[2].transactionHash, transactions[3].reversedHashHex)
        XCTAssertEqual(results[3].transactionHash, transactions[1].reversedHashHex)
    }

    func testOnInsertBlock() {
        let block = TestData.firstBlock
        let blockInfo = BlockInfo(
                headerHash: block.reversedHeaderHashHex,
                height: block.height,
                timestamp: block.header?.timestamp
        )
        dataProvider.onInsert(block: block)

        waitForMainQueue()

        verify(mockDataProviderDelegate).lastBlockInfoUpdated(lastBlockInfo: equal(to: blockInfo))
        XCTAssertEqual(dataProvider.balance, 0)
        XCTAssertEqual(dataProvider.lastBlockInfo, blockInfo)
    }

    func testBlockAdded_UnspentOutputsExist() {
        stub(mockUnspentOutputProvider) { mock in
            when(mock.balance.get).thenReturn(3)
        }

        try! realm.write {
            realm.add(TestData.firstBlock)
        }
        dataProvider.onInsert(block: TestData.firstBlock)

        waitForMainQueue()

        verify(mockDataProviderDelegate).balanceUpdated(balance: equal(to: 3))
        XCTAssertEqual(dataProvider.balance, 3)
    }

    func testTransactionsExist() {
        let transaction = TestData.p2pkTransaction
        transaction.isMine = true
        let transactionInfo = TransactionInfo(transactionHash: transaction.reversedHashHex, from: [TransactionAddressInfo](), to: [TransactionAddressInfo](), amount: 0, blockHeight: nil, timestamp: 0)

        stub(mockUnspentOutputProvider) { mock in
            when(mock.balance.get).thenReturn(3)
        }

        try! realm.write {
            realm.add(transaction)
        }
        dataProvider.onUpdate(updated: [], inserted: [transaction])

        waitForMainQueue()
        waitForMainQueue()

        verify(mockDataProviderDelegate).transactionsUpdated(inserted: equal(to: [transactionInfo]), updated: equal(to: [TransactionInfo]()))
        verify(mockDataProviderDelegate).balanceUpdated(balance: equal(to: 3))
        XCTAssertEqual(dataProvider.balance, 3)
    }

    private func transactions() -> [Transaction] {
        let transaction = Transaction(
                version: 0,
                inputs: [
                    TransactionInput(
                            withPreviousOutputTxReversedHex: Data(from: 1).hex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    TransactionOutput(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        let transaction2 = Transaction(
                version: 0,
                inputs: [
                    TransactionInput(
                            withPreviousOutputTxReversedHex: transaction.reversedHashHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    TransactionOutput(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
                    TransactionOutput(withValue: 0, index: 1, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        let transaction3 = Transaction(
                version: 0,
                inputs: [
                    TransactionInput(
                            withPreviousOutputTxReversedHex: transaction2.reversedHashHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    TransactionOutput(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
                ],
                lockTime: 0
        )

        let transaction4 = Transaction(
                version: 0,
                inputs: [
                    TransactionInput(
                            withPreviousOutputTxReversedHex: transaction2.reversedHashHex,
                            previousOutputIndex: 1,
                            script: Data(from: 999999999999),
                            sequence: 0
                    ),
                    TransactionInput(
                            withPreviousOutputTxReversedHex: transaction3.reversedHashHex,
                            previousOutputIndex: 0,
                            script: Data(from: 999999999999),
                            sequence: 0
                    )
                ],
                outputs: [
                    TransactionOutput(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
                ],
                lockTime: 0
        )

        return [transaction, transaction2, transaction3, transaction4]
    }

}
