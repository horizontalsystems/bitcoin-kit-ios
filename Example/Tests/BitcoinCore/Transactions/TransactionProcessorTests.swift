//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class TransactionProcessorTests: XCTestCase {
//    private var mockStorage: MockIStorage!
//    private var mockOutputExtractor: MockITransactionExtractor!
//    private var mockOutputAddressExtractor: MockITransactionOutputAddressExtractor!
//    private var mockInputExtractor: MockITransactionExtractor!
//    private var mockOutputsCache: MockIOutputsCache!
//    private var mockAddressManager: MockIPublicKeyManager!
//    private var mockBlockchainDataListener: MockIBlockchainDataListener!
//    private var mockTransactionListener: MockITransactionListener!
//    private var mockIrregularOutputFinder: MockIIrregularOutputFinder!
//    private var mockTransactionInfoConverter: MockITransactionInfoConverter!
//
//    private var generatedDate: Date!
//    private var dateGenerator: (() -> Date)!
//
//    private var transactionProcessor: TransactionProcessor!
//
//    override func setUp() {
//        super.setUp()
//
//        generatedDate = Date()
//        dateGenerator = {
//            return self.generatedDate
//        }
//
//        mockStorage = MockIStorage()
//        mockOutputExtractor = MockITransactionExtractor()
//        mockOutputAddressExtractor = MockITransactionOutputAddressExtractor()
//        mockInputExtractor = MockITransactionExtractor()
//        mockOutputsCache = MockIOutputsCache()
//        mockAddressManager = MockIPublicKeyManager()
//        mockBlockchainDataListener = MockIBlockchainDataListener()
//        mockTransactionListener = MockITransactionListener()
//        mockIrregularOutputFinder = MockIIrregularOutputFinder()
//        mockTransactionInfoConverter = MockITransactionInfoConverter()
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: any())).thenReturn(nil)
//            when(mock.add(transaction: any())).thenDoNothing()
//            when(mock.update(transaction: any())).thenDoNothing()
//            when(mock.update(block: any())).thenDoNothing()
//        }
//        stub(mockOutputsCache) { mock in
//            when(mock.add(fromOutputs: any())).thenDoNothing()
//            when(mock.hasOutputs(forInputs: any())).thenReturn(false)
//        }
//        stub(mockOutputExtractor) { mock in
//            when(mock.extract(transaction: any())).thenDoNothing()
//        }
//        stub(mockOutputAddressExtractor) { mock in
//            when(mock.extractOutputAddresses(transaction: any())).thenDoNothing()
//        }
//        stub(mockInputExtractor) { mock in
//            when(mock.extract(transaction: any())).thenDoNothing()
//        }
//        stub(mockAddressManager) { mock in
//            when(mock.gapShifts()).thenReturn(false)
//        }
//        stub(mockBlockchainDataListener) { mock in
//            when(mock.onUpdate(updated: any(), inserted: any(), inBlock: any())).thenDoNothing()
//            when(mock.onDelete(transactionHashes: any())).thenDoNothing()
//            when(mock.onInsert(block: any())).thenDoNothing()
//        }
//        stub(mockTransactionListener) { mock in
//            when(mock.onReceive(transaction: any())).thenDoNothing()
//        }
//        stub(mockIrregularOutputFinder) { mock in
//            when(mock.hasIrregularOutput(outputs: any())).thenReturn(false)
//        }
//
//        transactionProcessor = TransactionProcessor(
//                storage: mockStorage, outputExtractor: mockOutputExtractor, inputExtractor: mockInputExtractor, outputsCache: mockOutputsCache,
//                outputAddressExtractor: mockOutputAddressExtractor, addressManager: mockAddressManager, irregularOutputFinder: mockIrregularOutputFinder,
//                transactionInfoConverter: mockTransactionInfoConverter, listener: mockBlockchainDataListener, dateGenerator: dateGenerator
//        )
//        transactionProcessor.transactionListener = mockTransactionListener
//    }
//
//    override func tearDown() {
//        mockStorage = nil
//        mockOutputExtractor = nil
//        mockInputExtractor = nil
//        mockOutputsCache = nil
//        transactionProcessor = nil
//        mockBlockchainDataListener = nil
//        mockIrregularOutputFinder = nil
//
//        generatedDate = nil
//        dateGenerator = nil
//
//        super.tearDown()
//    }
//
//    func testProcessCreated() {
//        let transaction = TestData.p2pkhTransaction
//
//        try! transactionProcessor.processCreated(transaction: transaction)
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [Transaction]()), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verifyNoMoreInteractions(mockOutputAddressExtractor)
//        verifyNoMoreInteractions(mockInputExtractor)
//    }
//
//    func testProcessCreated_isMine() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        try! transactionProcessor.processCreated(transaction: transaction)
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
//        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
//    }
//
//    func testProcessCreated_TransactionExists() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//
//        do {
//            try transactionProcessor.processCreated(transaction: transaction)
//            XCTFail("Expecting error")
//        } catch let error as TransactionCreator.CreationError {
//            XCTAssertEqual(error, TransactionCreator.CreationError.transactionAlreadyExists)
//        } catch {
//            XCTFail("Unexpected error")
//        }
//
//        verify(mockOutputExtractor, never()).extract(transaction: any())
//        verify(mockOutputsCache, never()).hasOutputs(forInputs: any())
//        verify(mockBlockchainDataListener, never()).onUpdate(updated: any(), inserted: any(), inBlock: any())
//        verify(mockStorage, never()).add(transaction: any())
//        verify(mockOutputAddressExtractor, never()).extractOutputAddresses(transaction: any())
//        verify(mockInputExtractor, never()).extract(transaction: any())
//    }
//
//    func testProcessCreated_HasIrregularOutput() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        stub(mockIrregularOutputFinder) { mock in
//            when(mock.hasIrregularOutput(outputs: equal(to: transaction.outputs))).thenReturn(true)
//        }
//
//        do {
//            try transactionProcessor.processCreated(transaction: transaction)
//            XCTFail("Expecting error")
//        } catch _ as BloomFilterManager.BloomFilterExpired {
//        } catch {
//            XCTFail("Unexpected error")
//        }
//    }
//
//    func testProcessReceived_TransactionExists() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.status = .new
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//
//        verify(mockOutputExtractor, never()).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache, never()).hasOutputs(forInputs: any())
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transaction.header]), inserted: equal(to: []), inBlock: equal(to: nil))
//        verify(mockStorage).update(transaction: equal(to: transaction.header))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nil)
//        XCTAssertEqual(transaction.header.order, 0)
//    }
//
//    func testProcessReceived_SeveralMempoolTransactions() {
//        let transactions = self.transactions()
//        for transaction in transactions {
//            transaction.header.isMine = true
//            transaction.header.timestamp = 0
//            transaction.header.order = 0
//        }
//        transactions[1].header.status = .new
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transactions[1].header.dataHash))).thenReturn(transactions[1].header)
//            when(mock.transaction(byHash: equal(to: transactions[3].header.dataHash))).thenReturn(transactions[3].header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transactions[3], transactions[1], transactions[2], transactions[0]], inBlock: nil, skipCheckBloomFilter: false)
//
//        verify(mockStorage).add(transaction: equal(to: transactions[0]))
//        verify(mockStorage).update(transaction: equal(to: transactions[1].header))
//        verify(mockStorage).add(transaction: equal(to: transactions[2]))
//        verify(mockStorage).update(transaction: equal(to: transactions[3].header))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transactions[1].header, transactions[3].header]), inserted: equal(to: [transactions[0].header, transactions[2].header]), inBlock: equal(to: nil))
//
//        for (i, transaction) in transactions.enumerated() {
//            XCTAssertEqual(transaction.header.blockHash, nil)
//            XCTAssertEqual(transaction.header.status, .relayed)
//            XCTAssertEqual(transaction.header.order, i)
//            XCTAssertEqual(transaction.header.timestamp, Int(generatedDate.timeIntervalSince1970))
//        }
//    }
//
//    func testProcessReceivedMempool_After_Block_TransactionExists() {
//        let transaction = TestData.p2pkhTransaction
//        let block = TestData.firstBlock
//        transaction.header.status = .new
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: block, skipCheckBloomFilter: false)
//        verify(mockStorage).update(transaction: equal(to: transaction.header))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transaction.header]), inserted: equal(to: []), inBlock: equal(to: block))
//
//        reset(mockStorage, mockBlockchainDataListener)
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//
//        verify(mockStorage, never()).update(transaction: equal(to: transaction.header))
//        verify(mockBlockchainDataListener, never()).onUpdate(updated: equal(to: [transaction.header]), inserted: equal(to: []), inBlock: equal(to: nil))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, block.headerHash)
//        XCTAssertEqual(transaction.header.timestamp, block.timestamp)
//        XCTAssertEqual(transaction.header.order, 0)
//
//    }
//
//    func testProcessReceivedBlock_After_Block_TransactionExists() {
//        let transaction = TestData.p2pkhTransaction
//        let block = TestData.firstBlock
//        let nextBlock = TestData.secondBlock
//        transaction.header.status = .new
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: block, skipCheckBloomFilter: false)
//        verify(mockStorage).update(transaction: equal(to: transaction.header))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transaction.header]), inserted: equal(to: []), inBlock: equal(to: block))
//
//        reset(mockStorage, mockBlockchainDataListener)
//        stub(mockStorage) { mock in
//            when(mock.update(transaction: any())).thenDoNothing()
//            when(mock.update(block: any())).thenDoNothing()
//            when(mock.transaction(byHash: equal(to: transaction.header.dataHash))).thenReturn(transaction.header)
//        }
//        stub(mockBlockchainDataListener) { mock in
//            when(mock.onUpdate(updated: any(), inserted: any(), inBlock: any())).thenDoNothing()
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nextBlock, skipCheckBloomFilter: false)
//
//        verify(mockStorage).update(transaction: equal(to: transaction.header))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transaction.header]), inserted: equal(to: []), inBlock: equal(to: nextBlock))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nextBlock.headerHash)
//        XCTAssertEqual(transaction.header.timestamp, nextBlock.timestamp)
//        XCTAssertEqual(transaction.header.order, 0)
//    }
//
//
//    func testProcessReceived_SeveralTransactionsInBlock() {
//        let transactions = self.transactions()
//        let block = TestData.firstBlock
//
//        for transaction in transactions {
//            transaction.header.isMine = true
//            transaction.header.timestamp = 0
//            transaction.header.order = 0
//        }
//        transactions[1].header.status = .new
//
//        stub(mockStorage) { mock in
//            when(mock.transaction(byHash: equal(to: transactions[1].header.dataHash))).thenReturn(transactions[1].header)
//            when(mock.transaction(byHash: equal(to: transactions[3].header.dataHash))).thenReturn(transactions[3].header)
//        }
//
//        try! transactionProcessor.processReceived(transactions: [transactions[3], transactions[1], transactions[2], transactions[0]], inBlock: block, skipCheckBloomFilter: false)
//
//        verify(mockStorage).add(transaction: equal(to: transactions[0]))
//        verify(mockStorage).update(transaction: equal(to: transactions[1].header))
//        verify(mockStorage).add(transaction: equal(to: transactions[2]))
//        verify(mockStorage).update(transaction: equal(to: transactions[3].header))
//        verify(mockStorage).update(block: equal(to: block))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: [transactions[1].header, transactions[3].header]), inserted: equal(to: [transactions[0].header, transactions[2].header]), inBlock: equal(to: block))
//
//        for (i, transaction) in transactions.enumerated() {
//            XCTAssertEqual(transaction.header.blockHash, block.headerHash)
//            XCTAssertEqual(transaction.header.status, .relayed)
//            XCTAssertEqual(transaction.header.order, i)
//            XCTAssertEqual(transaction.header.timestamp, block.header.timestamp)
//        }
//    }
//
//    func testProcessReceived_TransactionNotExists_Mine() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
//        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockTransactionListener).onReceive(transaction: equal(to: transaction))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nil)
//    }
//
//    func testProcessReceived_TransactionNotExists_NotMine() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = false
//
//        try! transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockStorage, never()).add(transaction: any())
//        verify(mockTransactionListener).onReceive(transaction: equal(to: transaction))
//        verifyNoMoreInteractions(mockBlockchainDataListener)
//        verifyNoMoreInteractions(mockOutputAddressExtractor)
//        verifyNoMoreInteractions(mockInputExtractor)
//    }
//
//    func testProcessReceived_TransactionNotExists_Mine_GapShifts() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        stub(mockAddressManager) { mock in
//            when(mock.gapShifts()).thenReturn(true)
//        }
//
//        do {
//            try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//            XCTFail("Should throw exception")
//        } catch _ as BloomFilterManager.BloomFilterExpired {
//        } catch {
//            XCTFail("Unknown error thrown")
//        }
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
//        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nil)
//    }
//
//    func testProcessReceived_TransactionNotExists_Mine_HasIrregularOutputs() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = true
//
//        stub(mockIrregularOutputFinder) { mock in
//            when(mock.hasIrregularOutput(outputs: equal(to: transaction.outputs))).thenReturn(true)
//        }
//
//        do {
//            try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//            XCTFail("Should throw exception")
//        } catch _ as BloomFilterManager.BloomFilterExpired {
//        } catch {
//            XCTFail("Unknown error thrown")
//        }
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
//        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nil)
//    }
//
//    func testProcessReceived_TransactionNotExists_Mine_GapShifts_CheckBloomFilterFalse() {
//        let transaction = TestData.p2wpkhTransaction
//        transaction.header.isMine = true
//        transaction.outputs[0].publicKeyPath = TestData.pubKey().path
//
//        do {
//            try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: true)
//        } catch {
//            XCTFail("Unknown error thrown")
//        }
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockBlockchainDataListener).onUpdate(updated: equal(to: []), inserted: equal(to: [transaction.header]), inBlock: equal(to: nil))
//        verify(mockStorage).add(transaction: equal(to: transaction))
//        verify(mockOutputAddressExtractor).extractOutputAddresses(transaction: equal(to: transaction))
//        verify(mockInputExtractor).extract(transaction: equal(to: transaction))
//
//        XCTAssertEqual(transaction.header.status, TransactionStatus.relayed)
//        XCTAssertEqual(transaction.header.blockHash, nil)
//    }
//
//    func testProcessReceived_TransactionNotExists_NotMine_GapShifts() {
//        let transaction = TestData.p2pkhTransaction
//        transaction.header.isMine = false
//
//        stub(mockAddressManager) { mock in
//            when(mock.gapShifts()).thenReturn(true)
//        }
//
//        do {
//            try transactionProcessor.processReceived(transactions: [transaction], inBlock: nil, skipCheckBloomFilter: false)
//        } catch {
//            XCTFail("Shouldn't throw exception")
//        }
//
//        verify(mockOutputExtractor).extract(transaction: equal(to: transaction))
//        verify(mockOutputsCache).hasOutputs(forInputs: equal(to: transaction.inputs))
//        verify(mockStorage, never()).add(transaction: any())
//        verifyNoMoreInteractions(mockBlockchainDataListener)
//        verifyNoMoreInteractions(mockOutputAddressExtractor)
//        verifyNoMoreInteractions(mockInputExtractor)
//    }
//
//    func testProcessReceived_TransactionNotInTopologicalOrder() {
//        let transactions = self.transactions()
//        var calledTransactions = [FullTransaction]()
//
//        stub(mockOutputExtractor) { mock in
//            when(mock.extract(transaction: any())).then { transaction in
//                calledTransactions.append(transaction)
//            }
//        }
//
//        for i in 0..<4 {
//            for j in 0..<4 {
//                for k in 0..<4 {
//                    for l in 0..<4 {
//                        if [0, 1, 2, 3].contains(where: { $0 != i && $0 != j && $0 != k && $0 != l }) {
//                            continue
//                        }
//
//                        calledTransactions = []
//
//                        try! transactionProcessor.processReceived(transactions: [transactions[i], transactions[j], transactions[k], transactions[l]], inBlock: nil, skipCheckBloomFilter: false)
//
//                        verifyNoMoreInteractions(mockBlockchainDataListener)
//
//                        for (m, transaction) in calledTransactions.enumerated() {
//                            XCTAssertEqual(transaction.header.dataHash, transactions[m].header.dataHash)
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//
//    private func transactions() -> [FullTransaction] {
//        let transaction = FullTransaction(
//                header: Transaction(version: 0, lockTime: 0),
//                inputs: [
//                    Input(
//                            withPreviousOutputTxHash: Data(from: 1),
//                            previousOutputIndex: 0,
//                            script: Data(from: 999999999999),
//                            sequence: 0
//                    )
//                ],
//                outputs: [
//                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//                ]
//        )
//
//        let transaction2 = FullTransaction(
//                header: Transaction(version: 0, lockTime: 0),
//                inputs: [
//                    Input(
//                            withPreviousOutputTxHash: transaction.header.dataHash,
//                            previousOutputIndex: 0,
//                            script: Data(from: 999999999999),
//                            sequence: 0
//                    )
//                ],
//                outputs: [
//                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
//                    Output(withValue: 0, index: 1, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//                ]
//        )
//
//        let transaction3 = FullTransaction(
//                header: Transaction(version: 0, lockTime: 0),
//                inputs: [
//                    Input(
//                            withPreviousOutputTxHash: transaction2.header.dataHash,
//                            previousOutputIndex: 0,
//                            script: Data(from: 999999999999),
//                            sequence: 0
//                    )
//                ],
//                outputs: [
//                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data()),
//                ]
//        )
//
//        let transaction4 = FullTransaction(
//                header: Transaction(version: 0, lockTime: 0),
//                inputs: [
//                    Input(
//                            withPreviousOutputTxHash: transaction2.header.dataHash,
//                            previousOutputIndex: 1,
//                            script: Data(from: 999999999999),
//                            sequence: 0
//                    ),
//                    Input(
//                            withPreviousOutputTxHash: transaction3.header.dataHash,
//                            previousOutputIndex: 0,
//                            script: Data(from: 999999999999),
//                            sequence: 0
//                    )
//                ],
//                outputs: [
//                    Output(withValue: 0, index: 0, lockingScript: Data(hex: "9999999999")!, type: .p2pk, keyHash: Data())
//                ]
//        )
//
//        return [transaction, transaction2, transaction3, transaction4]
//    }
//
//}
