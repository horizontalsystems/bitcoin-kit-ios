//import XCTest
//import Cuckoo
//import RxSwift
//@testable import BitcoinCore
//
//class DataProviderTests: XCTestCase {
//    private var mockStorage: MockIStorage!
//    private var mockAddressManager: MockIPublicKeyManager!
//    private var mockAddressConverter: MockIAddressConverter!
//    private var mockPaymentAddressParser: MockIPaymentAddressParser!
//    private var mockUnspentOutputProvider: MockIUnspentOutputProvider!
//    private var mockTransactionCreator: MockITransactionCreator!
//    private var mockTransactionBuilder: MockITransactionBuilder!
//    private var mockNetwork: MockINetwork!
//    private var mockDataProviderDelegate: MockIDataProviderDelegate!
//
//    private var dataProvider: DataProvider!
//
//    override func setUp() {
//        super.setUp()
//
//        mockStorage = MockIStorage()
//        mockAddressManager = MockIPublicKeyManager()
//        mockAddressConverter = MockIAddressConverter()
//        mockPaymentAddressParser = MockIPaymentAddressParser()
//        mockUnspentOutputProvider = MockIUnspentOutputProvider()
//        mockTransactionCreator = MockITransactionCreator()
//        mockTransactionBuilder = MockITransactionBuilder()
//        mockNetwork = MockINetwork()
//        mockDataProviderDelegate = MockIDataProviderDelegate()
//
//        stub(mockStorage) { mock in
//            when(mock.lastBlock.get).thenReturn(TestData.checkpointBlock)
//        }
//        stub(mockUnspentOutputProvider) { mock in
//            when(mock.balance.get).thenReturn(0)
//        }
//        stub(mockDataProviderDelegate) { mock in
//            when(mock.transactionsUpdated(inserted: any(), updated: any())).thenDoNothing()
//            when(mock.balanceUpdated(balance: any())).thenDoNothing()
//            when(mock.lastBlockInfoUpdated(lastBlockInfo: any())).thenDoNothing()
//        }
//
//        dataProvider = DataProvider(
//                storage: mockStorage, addressManager: mockAddressManager, addressConverter: mockAddressConverter,
//                paymentAddressParser: mockPaymentAddressParser, unspentOutputProvider: mockUnspentOutputProvider,
//                transactionCreator: mockTransactionCreator, transactionBuilder: mockTransactionBuilder, network: mockNetwork, debounceTime: 0
//        )
//        dataProvider.delegate = mockDataProviderDelegate
//    }
//
//    override func tearDown() {
//        mockStorage = nil
//        mockAddressManager = nil
//        mockAddressConverter = nil
//        mockPaymentAddressParser = nil
//        mockUnspentOutputProvider = nil
//        mockTransactionCreator = nil
//        mockTransactionBuilder = nil
//        mockNetwork = nil
//        mockDataProviderDelegate = nil
//
//        dataProvider = nil
//
//        super.tearDown()
//    }
//
//    func testTransactions() {
//        let disposeBag = DisposeBag()
//        let transactions = self.transactions()
//
//        var results = [TransactionInfo]()
//        dataProvider.transactions(fromHash: nil, limit: 3).subscribe(
//                onSuccess: { transactionInfos in
//                    results = transactionInfos
//                }
//        ).disposed(by: disposeBag)
//        waitForMainQueue()
//
//        XCTAssertEqual(results.count, 3)
//        XCTAssertEqual(results[0].transactionHash, transactions[3].dataHashReversedHex)
//        XCTAssertEqual(results[1].transactionHash, transactions[2].dataHashReversedHex)
//        XCTAssertEqual(results[2].transactionHash, transactions[1].dataHashReversedHex)
//    }
//
//    func testTransactions_FromHashGiven() {
//        let disposeBag = DisposeBag()
//        let transactions = self.transactions()
//
//        // Sort by timestamps
//        var results = [TransactionInfo]()
//        dataProvider.transactions(fromHash: transactions[3].dataHashReversedHex, limit: 2).subscribe(
//                onSuccess: { transactionInfos in
//                    results = transactionInfos
//                }
//        ).disposed(by: disposeBag)
//        waitForMainQueue()
//
//        XCTAssertEqual(results.count, 2)
//        XCTAssertEqual(results[0].transactionHash, transactions[2].dataHashReversedHex)
//        XCTAssertEqual(results[1].transactionHash, transactions[1].dataHashReversedHex)
//
//        // Sort by timestamps and order
//        dataProvider.transactions(fromHash: transactions[1].dataHashReversedHex, limit: 3).subscribe(
//                onSuccess: { transactionInfos in
//                    results = transactionInfos
//                }
//        ).disposed(by: disposeBag)
//        waitForMainQueue()
//
//        XCTAssertEqual(results.count, 1)
//        XCTAssertEqual(results[0].transactionHash, transactions[0].dataHashReversedHex)
//    }
//
//    func testTransactions_LimitNotGiven() {
//        let disposeBag = DisposeBag()
//        let transactions = self.transactions()
//
//        // Sort by timestamps
//        var results = [TransactionInfo]()
//        dataProvider.transactions(fromHash: nil, limit: nil).subscribe(
//                onSuccess: { transactionInfos in
//                    results = transactionInfos
//                }
//        ).disposed(by: disposeBag)
//        waitForMainQueue()
//
//        XCTAssertEqual(results.count, 4)
//        XCTAssertEqual(results[0].transactionHash, transactions[3].dataHashReversedHex)
//        XCTAssertEqual(results[1].transactionHash, transactions[2].dataHashReversedHex)
//        XCTAssertEqual(results[2].transactionHash, transactions[1].dataHashReversedHex)
//        XCTAssertEqual(results[3].transactionHash, transactions[0].dataHashReversedHex)
//    }
//
//    func testOnInsertBlock() {
//        let block = TestData.firstBlock
//        let blockInfo = BlockInfo(
//                headerHash: block.headerHashReversedHex,
//                height: block.height,
//                timestamp: block.header.timestamp
//        )
//        dataProvider.onInsert(block: block)
//
//        waitForMainQueue()
//
//        verify(mockDataProviderDelegate).lastBlockInfoUpdated(lastBlockInfo: equal(to: blockInfo))
//        XCTAssertEqual(dataProvider.balance, 0)
//        XCTAssertEqual(dataProvider.lastBlockInfo, blockInfo)
//    }
//
//    func testBlockAdded_UnspentOutputsExist() {
//        //        stub(mockUnspentOutputProvider) { mock in
//        //            when(mock.balance.get).thenReturn(3)
//        //        }
//        //
//        //        try! realm.write {
//        //            realm.add(TestData.firstBlock)
//        //        }
//        //        dataProvider.onInsert(block: TestData.firstBlock)
//        //
//        //        waitForMainQueue()
//        //
//        //        verify(mockDataProviderDelegate).balanceUpdated(balance: equal(to: 3))
//        //        XCTAssertEqual(dataProvider.balance, 3)
//    }
//
//    func testTransactionsExist() {
//        //        let transaction = TestData.p2pkTransaction
//        //        transaction.isMine = true
//        //        let transactionInfo = TransactionInfo(transactionHash: transaction.hashReversedHex, from: [TransactionAddressInfo](), to: [TransactionAddressInfo](), amount: 0, blockHeight: nil, timestamp: 0)
//        //
//        //        stub(mockUnspentOutputProvider) { mock in
//        //            when(mock.balance.get).thenReturn(3)
//        //        }
//        //
//        //        try! realm.write {
//        //            realm.add(transaction)
//        //        }
//        //        dataProvider.onUpdate(updated: [], inserted: [transaction])
//        //
//        //        waitForMainQueue()
//        //        waitForMainQueue()
//        //
//        //        verify(mockDataProviderDelegate).transactionsUpdated(inserted: equal(to: [transactionInfo]), updated: equal(to: [TransactionInfo]()))
//        //        verify(mockDataProviderDelegate).balanceUpdated(balance: equal(to: 3))
//        //        XCTAssertEqual(dataProvider.balance, 3)
//    }
//
//    private func transactions() -> [Transaction] {
//        let transaction = Transaction(version: 0, lockTime: 0)
//
//        let inputs = [
//            Input(
//                    withPreviousOutputTxReversedHex: Data(from: 1).hex,
//                    previousOutputIndex: 0,
//                    script: Data(from: 999999999999),
//                    sequence: 0
//            )
//        ]
//        let outputs = [
//            Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//        ]
//
//
//        let transaction2 = Transaction(version: 0, lockTime: 0)
//        let inputs2 = [
//            Input(
//                    withPreviousOutputTxReversedHex: transaction.dataHashReversedHex,
//                    previousOutputIndex: 0,
//                    script: Data(from: 999999999999),
//                    sequence: 0
//            )
//        ]
//        let outputs2 = [
//            Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
//            Output(withValue: 0, index: 1, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//        ]
//
//        let transaction3 = Transaction(version: 0, lockTime: 0)
//        let inputs3 = [
//            Input(
//                    withPreviousOutputTxReversedHex: transaction2.dataHashReversedHex,
//                    previousOutputIndex: 0,
//                    script: Data(from: 999999999999),
//                    sequence: 0
//            )
//        ]
//        let outputs3 = [
//            Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
//        ]
//
//        let transaction4 = Transaction(version: 0, lockTime: 0)
//        let inputs4 = [
//            Input(
//                    withPreviousOutputTxReversedHex: transaction2.dataHashReversedHex,
//                    previousOutputIndex: 1,
//                    script: Data(from: 999999999999),
//                    sequence: 0
//            ),
//            Input(
//                    withPreviousOutputTxReversedHex: transaction3.dataHashReversedHex,
//                    previousOutputIndex: 0,
//                    script: Data(from: 999999999999),
//                    sequence: 0
//            )
//        ]
//        let outputs4 = [
//            Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//        ]
//
//        let transactions = [transaction, transaction2, transaction3, transaction4]
//        let allInputs = [inputs, inputs2, inputs3, inputs4]
//        let allOutputs = [outputs, outputs2, outputs3, outputs4]
//
//        stub(mockStorage) { mock in
//            for (i, transaction) in transactions.enumerated() {
//                transaction.dataHashReversedHex = String(i)
//                transaction.timestamp = i
//                when(mock.transaction(byHashHex: equal(to: transaction.dataHashReversedHex))).thenReturn(transaction)
//                when(mock.inputs(ofTransaction: equal(to: transaction))).thenReturn(allInputs[i])
//                when(mock.outputs(ofTransaction: equal(to: transaction))).thenReturn(allOutputs[i])
//
//            }
//            when(mock.previousOutput(ofInput: any())).thenReturn(nil)
//            when(mock.transactions(sortedBy: equal(to: Transaction.Columns.timestamp), secondSortedBy: equal(to: Transaction.Columns.order), ascending: false)).thenReturn(Array(transactions.reversed()))
//        }
//
//        return transactions
//    }
//
//}
