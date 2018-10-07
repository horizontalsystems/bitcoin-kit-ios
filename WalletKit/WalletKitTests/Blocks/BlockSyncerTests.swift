import XCTest
import Cuckoo
import CryptoKit
import RealmSwift
@testable import WalletKit

class BlockSyncerTests: XCTestCase {

    private var mockValidatedBlockFactory: MockValidatedBlockFactory!
    private var mockProcessor: MockTransactionProcessor!
    private var mockProgressSyncer: MockProgressSyncer!
    private var syncer: BlockSyncer!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockValidatedBlockFactory = mockWalletKit.mockValidatedBlockFactory
        mockProcessor = mockWalletKit.mockTransactionProcessor
        mockProgressSyncer = mockWalletKit.mockProgressSyncer
        realm = mockWalletKit.realm

        stub(mockProcessor) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }
        stub(mockProgressSyncer) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }

        syncer = BlockSyncer(realmFactory: mockWalletKit.mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, processor: mockProcessor, progressSyncer: mockProgressSyncer, queue: DispatchQueue.main)
    }

    override func tearDown() {
        mockValidatedBlockFactory = nil
        mockProcessor = nil
        mockProgressSyncer = nil
        syncer = nil
        realm = nil

        super.tearDown()
    }

    func testHandle() {
        let transaction = TestData.p2pkhTransaction
        let checkpointBlock = TestData.checkpointBlock
        let block = TestData.firstBlock
        block.previousBlock = checkpointBlock

        try! realm.write {
            realm.add(block, update: true)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.reversedHeaderHashHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(realmBlock.synced, true)
        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandle_MultipleBlocks() {
        let transaction = TestData.p2pkhTransaction
        let transaction2 = TestData.p2pkTransaction
        let transaction3 = TestData.p2shTransaction
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        try! realm.write {
            realm.add(secondBlock, update: true)
        }

        let merkleBlock1 = MerkleBlock(header: firstBlock.header!, transactionHashes: [], transactions: [transaction])
        let merkleBlock2 = MerkleBlock(header: secondBlock.header!, transactionHashes: [], transactions: [transaction2, transaction3])

        syncer.handle(merkleBlocks: [merkleBlock1, merkleBlock2])

        waitForMainQueue()

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).last!
        XCTAssertEqual(realmBlock.headerHash, firstBlock.headerHash)
        XCTAssertEqual(realmBlock.synced, true)
        let realmTransactions = realmBlock.transactions
        assertTransactionEqual(tx1: transaction, tx2: realmTransactions[0])

        let realmBlock2 = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).last!
        XCTAssertEqual(realmBlock.headerHash, firstBlock.headerHash)
        XCTAssertEqual(realmBlock.synced, true)
        let realmTransactions2 = realmBlock2.transactions
        assertTransactionEqual(tx1: transaction2, tx2: realmTransactions2[0])
        assertTransactionEqual(tx1: transaction3, tx2: realmTransactions2[1])

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandle_EmptyTransactions() {
        let block = TestData.checkpointBlock

        try! realm.write {
            realm.add(block, update: true)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [])])

        waitForMainQueue()

        verify(mockProcessor, never()).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandle_ExistingTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new
        let block = TestData.firstBlock

        try! realm.write {
            realm.add(transaction, update: true)
        }
        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenReturn(block)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.reversedHeaderHashHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        XCTAssertEqual(realmBlock.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).enqueueRun()
    }

    func testHandle_ExistingBlockAndTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new
        let block = TestData.firstBlock

        try! realm.write {
            realm.add(block, update: true)
            realm.add(transaction, update: true)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        let realmTransaction = realm.objects(Transaction.self).last!

        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).enqueueRun()
    }

    func testHandle_NewBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.firstBlock

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenReturn(block)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.headerHash.reversedHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(realmBlock.synced, true)
        XCTAssertEqual(realmTransaction.block, realmBlock)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandle_ExistingBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.checkpointBlock
        let savedBlock = Factory().block(withHeaderHash: block.headerHash, height: 0)

        try! realm.write {
            realm.add(savedBlock, update: true)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        let realmBlock = realm.objects(Block.self).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: realmBlock.header!)), CryptoKit.sha256sha256(BlockHeaderSerializer.serialize(header: block.header!)))
        XCTAssertEqual(realmBlock.synced, true)
        XCTAssertEqual(realmTransaction.block, realmBlock)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandle_InvalidBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.firstBlock

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenThrow(BlockValidatorError.noCheckpointBlock)
        }

        syncer.handle(merkleBlocks: [MerkleBlock(header: block.header!, transactionHashes: [], transactions: [transaction])])

        waitForMainQueue()

        verify(mockProcessor, never()).enqueueRun()
        verify(mockProgressSyncer, never()).enqueueRun()
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
