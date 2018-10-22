import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import HSBitcoinKit

class BlockSyncerTests: XCTestCase {
    private var mockNetwork: MockINetwork!
    private var mockProgressSyncer: MockIProgressSyncer!
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
        mockProgressSyncer = MockIProgressSyncer()
        mockTransactionProcessor = MockITransactionProcessor()
        mockBlockchain = MockIBlockchain()
        mockAddressManager = MockIAddressManager()
        mockBloomFilterManager = MockIBloomFilterManager()

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

        stub(mockProgressSyncer) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }
        stub(mockTransactionProcessor) { mock in
            when(mock.process(transaction: any(), realm: any())).thenDoNothing()
        }
        stub(mockBlockchain) { mock in
//            when(mock.connect((merkleBlock: any(), realm: any())).thenReturn(newBlock1))
        }
        stub(mockAddressManager) { mock in
            when(mock.fillGap()).thenDoNothing()
        }

        syncer = BlockSyncer(
                realmFactory: mockRealmFactory, network: mockNetwork, progressSyncer: mockProgressSyncer,
                transactionProcessor: mockTransactionProcessor, blockchain: mockBlockchain, addressManager: mockAddressManager, bloomFilterManager: mockBloomFilterManager,
                hashCheckpointThreshold: 100
        )
    }

    override func tearDown() {
        mockNetwork = nil
        mockProgressSyncer = nil
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

}
