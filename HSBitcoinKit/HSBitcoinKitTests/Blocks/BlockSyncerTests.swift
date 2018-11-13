import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import HSBitcoinKit

class BlockSyncerTests: XCTestCase {
    private var mockNetwork: MockINetwork!
    private var mockBlockSyncerListener: MockBlockSyncerListener!
    private var mockTransactionProcessor: MockITransactionProcessor!
    private var mockBlockchain: MockIBlockchain!
    private var mockAddressManager: MockIAddressManager!
    private var mockBloomFilterManager: MockIBloomFilterManager!

    private var checkpointBlock: Block!
    private var newBlock1: Block!
    private var newBlock2: Block!
    private var newTransaction1: Transaction!
    private var newTransaction2: Transaction!
    private var merkleBlock1: MerkleBlock!
    private var merkleBlock2: MerkleBlock!

    private var syncer: BlockSyncer!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        let mockRealmFactory = MockIRealmFactory()
        stub(mockRealmFactory) { mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockNetwork = MockINetwork()
        mockBlockSyncerListener = MockBlockSyncerListener()
        mockTransactionProcessor = MockITransactionProcessor()
        mockBlockchain = MockIBlockchain()
        mockAddressManager = MockIAddressManager()
        mockBloomFilterManager = MockIBloomFilterManager()

        stub(mockNetwork) { mock in
            when(mock.checkpointBlock.get).thenReturn(TestData.checkpointBlock)
        }
        stub(mockBlockSyncerListener) { mock in
            when(mock.initialBestBlockHeightUpdated(height: any())).thenDoNothing()
            when(mock.currentBestBlockHeightUpdated(height: any())).thenDoNothing()
        }

        stub(mockTransactionProcessor) { mock in
            when(mock.process(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockBlockchain) { mock in
            when(mock.deleteBlocks(blocks: any(), realm: any())).thenDoNothing()
            when(mock.handleFork(realm: any())).thenDoNothing()
        }
        stub(mockAddressManager) { mock in
            when(mock.fillGap()).thenDoNothing()
        }
        stub(mockBloomFilterManager) { mock in
            when(mock.regenerateBloomFilter()).thenDoNothing()
        }

        syncer = BlockSyncer(
                realmFactory: mockRealmFactory, network: mockNetwork, listener: mockBlockSyncerListener,
                transactionProcessor: mockTransactionProcessor, blockchain: mockBlockchain, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                hashCheckpointThreshold: 100
        )

        verify(mockBlockSyncerListener).initialBestBlockHeightUpdated(height: equal(to: Int32(TestData.checkpointBlock.height)))

        checkpointBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", TestData.checkpointBlock.reversedHeaderHashHex).first!
        newBlock2 = TestData.secondBlock
        newBlock1 = newBlock2.previousBlock!
        newBlock1.previousBlock = checkpointBlock
        newTransaction1 = TestData.p2pkTransaction
        newTransaction2 = TestData.p2pkhTransaction
        newTransaction1.isMine = true
        newTransaction2.isMine = false
        merkleBlock1 = MerkleBlock(header: newBlock1.header!, transactionHashes: [], transactions: [newTransaction1, newTransaction2])
        merkleBlock2 = MerkleBlock(header: newBlock2.header!, transactionHashes: [], transactions: [])

    }

    override func tearDown() {
        mockNetwork = nil
        mockTransactionProcessor = nil
        mockBlockchain = nil
        mockAddressManager = nil
        realm = nil

        checkpointBlock = nil
        newBlock1 = nil
        newBlock2 = nil
        newTransaction1 = nil
        newTransaction2 = nil
        merkleBlock1 = nil
        merkleBlock2 = nil

        syncer = nil

        super.tearDown()
    }

    func testPrepareForDownload() {
        let transaction = TestData.p2pkTransaction
        transaction.block = newBlock1

        try! realm.write {
            realm.add(newBlock1)
            realm.add(BlockHash(withHeaderHash: newBlock1.headerHash, height: 0))
            realm.add(BlockHash(withHeaderHash: checkpointBlock.headerHash, height: 0))
            realm.add(transaction)
        }

        let newBlockHeaderHash = newBlock1.headerHash

        syncer.prepareForDownload()

        verify(mockAddressManager).fillGap()
        verify(mockBloomFilterManager).regenerateBloomFilter()
        verify(mockBlockchain).handleFork(realm: any())

        let equalFunction: (Results<Block>, Results<Block>) -> Bool =
                { $1.contains { block in block.headerHash == newBlockHeaderHash } && $1.count == 1 }
        verify(mockBlockchain).deleteBlocks(blocks: equal(to: realm.objects(Block.self), equalWhen: equalFunction), realm: any())

        XCTAssertEqual(realm.objects(BlockHash.self).count, 0)
    }

    func testLocalBestBlockHeight() {
        let secondBlock = TestData.secondBlock
        secondBlock.previousBlock!.previousBlock = realm.objects(Block.self).first

        try! realm.write {
            realm.add(secondBlock)
        }

        XCTAssertEqual(realm.objects(Block.self).count, 3)
        XCTAssertEqual(syncer.localBestBlockHeight, Int32(secondBlock.height))
    }

    func testPrepareForDownload_PreValidatedBlocks() {
        newBlock1 = Block(withHeaderHash: Data(hex: "1111111111111111")!, height: 1)
        try! realm.write {
            realm.add(newBlock1)
            realm.add(BlockHash(withHeaderHash: newBlock1.headerHash, height: 1))
        }

        let newBlockHeaderHash = newBlock1.headerHash

        syncer.prepareForDownload()

        verify(mockAddressManager).fillGap()
        verify(mockBloomFilterManager).regenerateBloomFilter()
        verify(mockBlockchain).handleFork(realm: any())

        let equalFunction: (Results<Block>, Results<Block>) -> Bool =
                { $1.contains { block in block.headerHash == newBlockHeaderHash } && $1.count == 1 }
        verify(mockBlockchain).deleteBlocks(blocks: equal(to: realm.objects(Block.self), equalWhen: equalFunction), realm: any())

        XCTAssertEqual(realm.objects(BlockHash.self).filter("headerHash = %@", newBlockHeaderHash).count, 1)
    }

    func testDownloadIterationCompleted_NeedToReDownloadIsTrue() {
        setTrueToNeedToReDownload()

        syncer.downloadIterationCompleted()

        verify(mockAddressManager).fillGap()
        verify(mockBloomFilterManager).regenerateBloomFilter()

        verifyNeedToReDownloadSet(to: false)
    }

    func testDownloadIterationCompleted_NeedToReDownloadIsFalse() {
        verifyNeedToReDownloadSet(to: false)

        syncer.downloadIterationCompleted()

        verify(mockAddressManager, never()).fillGap()
        verify(mockBloomFilterManager, never()).regenerateBloomFilter()
        verifyNeedToReDownloadSet(to: false)
    }

    func testDownloadCompleted() {
        syncer.downloadCompleted()
        verify(mockBlockchain).handleFork(realm: any())
    }

    func testDownloadFailed() {
        let transaction = TestData.p2pkTransaction
        transaction.block = newBlock1

        try! realm.write {
            realm.add(newBlock1)
            realm.add(BlockHash(withHeaderHash: newBlock1.headerHash, height: 0))
            realm.add(BlockHash(withHeaderHash: checkpointBlock.headerHash, height: 0))
            realm.add(transaction)
        }

        let newBlockHeaderHash = newBlock1.headerHash

        syncer.downloadFailed()

        verify(mockAddressManager).fillGap()
        verify(mockBloomFilterManager).regenerateBloomFilter()
        verify(mockBlockchain).handleFork(realm: any())

        let equalFunction: (Results<Block>, Results<Block>) -> Bool =
                { $1.contains { block in block.headerHash == newBlockHeaderHash } && $1.count == 1 }
        verify(mockBlockchain).deleteBlocks(blocks: equal(to: realm.objects(Block.self), equalWhen: equalFunction), realm: any())

        XCTAssertEqual(realm.objects(BlockHash.self).count, 0)
    }

    func testGetBlockHashes() {
        var blockHashes = [BlockHash]()
        for i in 0..<1000 {
            blockHashes.append(BlockHash(withHeaderHash: Data(from: i), height: [i-900, 0].max()!, order: i))
        }

        try! realm.write {
            realm.add(blockHashes)
        }

        let results = syncer.getBlockHashes()
        XCTAssertEqual(results.count, 500)
        XCTAssertEqual(results.first!.headerHash, blockHashes.first!.headerHash)
        XCTAssertEqual(results.last!.headerHash, blockHashes[499].headerHash)
    }

    func testGetBlockLocatorHashes_BlockHashesExist() {
        var blocks = [Block]()
        var blockHashes = [BlockHash]()

        for i in 0..<20 {
            blocks.append(Block(withHeaderHash: Data(from: i), height: i+1))
        }
        for i in 0..<10 {
            blockHashes.append(BlockHash(withHeaderHash: Data(from: i + 100), height: [i-900, 0].max()!, order: i))
        }

        try! realm.write {
            realm.add(blocks)
            realm.add(blockHashes)
        }

        let results = syncer.getBlockLocatorHashes(peerLastBlockHeight: 0)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], blockHashes.last!.headerHash)
        XCTAssertEqual(results[1], TestData.checkpointBlock.headerHash)
    }

    func testGetBlockLocatorHashes_NoBlockHashes() {
        var blocks = [Block]()
        for i in 0..<20 {
            blocks.append(Block(withHeaderHash: Data(from: i), height: i+10000000))
        }

        try! realm.write {
            realm.add(blocks)
        }

        let results = syncer.getBlockLocatorHashes(peerLastBlockHeight: 0)
        XCTAssertEqual(results.count, 11)
        for i in 0..<10 {
            XCTAssertEqual(results[i], blocks[19-i].headerHash)
        }
        XCTAssertEqual(results[10], TestData.checkpointBlock.headerHash)
    }

    func testAdd_BlockHashesExist() {
        var blockHashDatas = [Data]()
        for i in 0..<10 {
            blockHashDatas.append(Data(from: i))
        }

        try! realm.write {
            realm.add(BlockHash(withHeaderHash: Data(from: 10000), height: 0, order: 10))
        }
        syncer.add(blockHashes: blockHashDatas)

        XCTAssertEqual(realm.objects(BlockHash.self).count, 11)
        for i in 0..<10 {
            let blockHash = realm.objects(BlockHash.self).filter("headerHash = %@", Data(from: i)).first!
            XCTAssertEqual(blockHash.order, 11 + i)
            XCTAssertEqual(blockHash.height, 0)
        }
    }

    func testHandleMerkleBlock() {
        let merkleBlock = MerkleBlock(header: TestData.secondBlock.header!, transactionHashes: [], transactions: [])
        let block = TestData.secondBlock
        let blockHash = BlockHash(withHeaderHash: block.headerHash, height: block.height)

        try! realm.write {
            realm.add(blockHash)
        }

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(block)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
        }

        try! syncer.handle(merkleBlock: merkleBlock)
        verify(mockBlockchain).connect(merkleBlock: equal(to: merkleBlock), realm: any())
        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: false), realm: any())
        verify(mockBlockSyncerListener).currentBestBlockHeightUpdated(height: Int32(block.height))
        XCTAssertEqual(realm.objects(BlockHash.self).count, 0)
        verifyNeedToReDownloadSet(to: false)
    }

    func testHandleMerkleBlock_PreValidatedBlock() {
        let merkleBlock = MerkleBlock(header: TestData.secondBlock.header!, transactionHashes: [], transactions: [])
        merkleBlock.height = 1000
        let block = TestData.secondBlock
        let forceAddedBlock = Block(withHeaderHash: Data(from: 100000000), height: merkleBlock.height!)
        let blockHash = BlockHash(withHeaderHash: block.headerHash, height: block.height)

        try! realm.write {
            realm.add(blockHash)
        }

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(forceAddedBlock)
            when(mock.forceAdd(merkleBlock: equal(to: merkleBlock), height: equal(to: merkleBlock.height!), realm: any())).thenReturn(forceAddedBlock)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: forceAddedBlock), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
        }

        try! syncer.handle(merkleBlock: merkleBlock)
        verify(mockBlockchain, never()).connect(merkleBlock: any(), realm: any())
        verify(mockBlockchain).forceAdd(merkleBlock: equal(to: merkleBlock), height: equal(to: merkleBlock.height!), realm: any())
        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: forceAddedBlock), skipCheckBloomFilter: equal(to: false), realm: any())
    }

    func testHandleMerkleBlock_ErrorWhileConnectingBlock() {
        let merkleBlock = MerkleBlock(header: TestData.secondBlock.header!, transactionHashes: [], transactions: [])

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenThrow(BlockValidatorError.noPreviousBlock)
        }

        do {
            try syncer.handle(merkleBlock: merkleBlock)
            XCTFail("Should throw an error")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
        } catch {
            XCTFail("Wrong error thrown")
        }

        verify(mockBlockchain).connect(merkleBlock: equal(to: merkleBlock), realm: any())
        verify(mockBlockchain, never()).forceAdd(merkleBlock: any(), height: any(), realm: any())
        verify(mockTransactionProcessor, never()).process(transactions: any(), inBlock: any(), skipCheckBloomFilter: any(), realm: any())
    }

    func testHandleMerkleBlock_NeedToReDownloadTrue() {
        setTrueToNeedToReDownload()

        let merkleBlock = MerkleBlock(header: TestData.secondBlock.header!, transactionHashes: [], transactions: [])
        let block = TestData.secondBlock
        let blockHash = BlockHash(withHeaderHash: block.headerHash, height: block.height)

        try! realm.write {
            realm.add(blockHash)
        }

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(block)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
        }

        try! syncer.handle(merkleBlock: merkleBlock)
        verify(mockBlockchain).connect(merkleBlock: equal(to: merkleBlock), realm: any())
        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: true), realm: any())
        XCTAssertEqual(realm.objects(BlockHash.self).count, 1)
        verifyNeedToReDownloadSet(to: true)
    }

    func testHandleMerkleBlock_BloomFilterExpired() {
        let merkleBlock = MerkleBlock(header: TestData.secondBlock.header!, transactionHashes: [], transactions: [])
        let block = TestData.secondBlock
        let blockHash = BlockHash(withHeaderHash: block.headerHash, height: block.height)

        try! realm.write {
            realm.add(blockHash)
        }

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(block)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: any(), realm: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
        }

        try! syncer.handle(merkleBlock: merkleBlock)
        verify(mockBlockchain).connect(merkleBlock: equal(to: merkleBlock), realm: any())
        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: equal(to: false), realm: any())
        XCTAssertEqual(realm.objects(BlockHash.self).count, 1)
        verifyNeedToReDownloadSet(to: true)
    }


    func testShouldRequestBlock() {
        try! realm.write {
            realm.add(newBlock1)
        }

        XCTAssertEqual(syncer.shouldRequestBlock(withHash: newBlock1.headerHash), false)
        XCTAssertEqual(syncer.shouldRequestBlock(withHash: newBlock2.headerHash), true)
    }


    private func verifyNeedToReDownloadSet(to value: Bool) {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [], transactions: [])
        let block = TestData.firstBlock

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(block)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: any(), realm: any())).thenDoNothing()
        }

        try? syncer.handle(merkleBlock: merkleBlock)

        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: value, realm: any())
    }

    private func setTrueToNeedToReDownload() {
        let merkleBlock = MerkleBlock(header: TestData.firstBlock.header!, transactionHashes: [], transactions: [])
        let block = TestData.firstBlock

        stub(mockBlockchain) { mock in
            when(mock.connect(merkleBlock: equal(to: merkleBlock), realm: any())).thenReturn(block)
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: false, realm: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
        }
        try? syncer.handle(merkleBlock: merkleBlock)

        stub(mockTransactionProcessor) { mock in
            when(mock.process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: true, realm: any())).thenThrow(BloomFilterManager.BloomFilterExpired())
        }
        try? syncer.handle(merkleBlock: merkleBlock)

        verify(mockTransactionProcessor).process(transactions: equal(to: []), inBlock: equal(to: block), skipCheckBloomFilter: true, realm: any())
    }

}
