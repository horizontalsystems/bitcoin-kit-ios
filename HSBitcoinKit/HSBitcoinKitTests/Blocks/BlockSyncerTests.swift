import XCTest
import Cuckoo
import HSCryptoKit
import RealmSwift
@testable import HSBitcoinKit

class BlockSyncerTests: XCTestCase {

    private var mockRealmFactory: MockRealmFactory!
    private var mockNetwork: MockNetworkProtocol!
    private var mockProgressSyncer: MockProgressSyncer!
    private var mockTransactionProcessor: MockTransactionProcessor!
    private var mockBlockchain: MockBlockchain!
    private var mockAddressManager: MockAddressManager!

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

        let mockBitcoinKit = MockBitcoinKit()

        mockRealmFactory = mockBitcoinKit.mockRealmFactory
        mockNetwork = mockBitcoinKit.mockNetwork
        mockProgressSyncer = mockBitcoinKit.mockProgressSyncer
        mockTransactionProcessor = mockBitcoinKit.mockTransactionProcessor
        mockBlockchain = mockBitcoinKit.mockBlockchain
        mockAddressManager = mockBitcoinKit.mockAddressManager
        realm = mockBitcoinKit.realm

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
            when(mock.fillGap(afterExternalKey: any(), afterInternalKey: any())).thenDoNothing()
        }

        syncer = BlockSyncer(
                realmFactory: mockRealmFactory, network: mockNetwork, progressSyncer: mockProgressSyncer,
                transactionProcessor: mockTransactionProcessor, blockchain: mockBlockchain, addressManager: mockAddressManager,
                hashCheckpointThreshold: 100
        )
    }

    override func tearDown() {
        mockRealmFactory = nil
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
