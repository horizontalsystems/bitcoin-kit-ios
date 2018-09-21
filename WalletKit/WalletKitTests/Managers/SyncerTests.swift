import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class SyncerTests: XCTestCase {

    class TestError: Error, CustomStringConvertible {
        private(set) var description: String = "test error"
    }

    private var mockRealmFactory: MockRealmFactory!
    private var mockHeaderSyncer: MockHeaderSyncer!
    private var mockHeaderHandler: MockHeaderHandler!
    private var mockTransactionHandler: MockTransactionHandler!
    private var syncer: Syncer!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockHeaderSyncer = mockWalletKit.mockHeaderSyncer
        mockHeaderHandler = mockWalletKit.mockHeaderHandler
        mockTransactionHandler = mockWalletKit.mockTransactionHandler
        realm = mockWalletKit.realm

        stub(mockHeaderHandler) { mock in
            when(mock.handle(headers: any())).thenDoNothing()
        }
        stub(mockTransactionHandler) { mock in
            when(mock.handle(merkleBlocks: any())).thenDoNothing()
            when(mock.handle(memPoolTransactions: any())).thenDoNothing()
        }

        syncer = Syncer(realmFactory: mockWalletKit.mockRealmFactory)
        syncer.headerSyncer = mockHeaderSyncer
        syncer.headerHandler = mockHeaderHandler
        syncer.transactionHandler = mockTransactionHandler
    }

    override func tearDown() {
        mockHeaderSyncer = nil
        mockHeaderHandler = nil
        mockTransactionHandler = nil
        syncer = nil

        realm = nil

        super.tearDown()
    }

    func testGetHeaderHashes() {
        let hashes: [Data] = [Data(bytes: [1, 2, 3])]

        stub(mockHeaderSyncer) { mock in
            when(mock.getHeaders()).thenReturn(hashes)
        }

        XCTAssertEqual(syncer.getHeadersHashes(), hashes)
    }

    func testRunHeaderHandler() {
        let headers: [BlockHeader] = [TestData.firstBlock.header!, TestData.secondBlock.header!]

        syncer.peerGroupDidReceive(headers: headers)

        verify(mockHeaderHandler).handle(headers: equal(to: headers))
    }

    func testRunHeaderHandler_Error() {
        let error = TestError()

        stub(mockHeaderHandler) { mock in
            when(mock.handle(headers: any())).thenThrow(error)
        }

        let headers: [BlockHeader] = [TestData.firstBlock.header!, TestData.secondBlock.header!]

        syncer.peerGroupDidReceive(headers: headers)
    }

    func testRunTransactions() {
        let blockHeader = TestData.checkpointBlock.header!
        let transaction = TestData.p2pkhTransaction
        let merkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [], transactions: [transaction])

        syncer.peerGroupDidReceive(merkleBlocks: [merkleBlock])
//        verify(mockTransactionHandler).handle(merkleBlocks: equal(to: [merkleBlock]))
    }

    func testRunTransactions_Error() {
        let error = TestError()
        stub(mockTransactionHandler) { mock in
            when(mock.handle(merkleBlocks: any())).thenThrow(error)
        }

        let blockHeader = TestData.checkpointBlock.header!
        let transaction = TestData.p2pkhTransaction
        let merkleBlock = MerkleBlock(header: blockHeader, transactionHashes: [], transactions: [transaction])

        syncer.peerGroupDidReceive(merkleBlocks: [merkleBlock])
    }

    func testRunTransactionHandler() {
        let transaction = TestData.p2pkhTransaction
        syncer.peerGroupDidReceive(transaction: transaction)

        verify(mockTransactionHandler).handle(memPoolTransactions: equal(to: [transaction]))
    }

    func testRunTransactionHandler_Error() {
        let error = TestError()

        stub(mockTransactionHandler) { mock in
            when(mock.handle(memPoolTransactions: any())).thenThrow(error)
        }

        let transaction = TestData.p2pkhTransaction
        syncer.peerGroupDidReceive(transaction: transaction)
    }

    func testShouldRequest_TransactionExists() {
        let transaction = TestData.p2pkhTransaction

        try! realm.write {
            realm.add(transaction)
        }

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), false)
    }

    func testShouldRequest_TransactionDoesntExists() {
        let transaction = TestData.p2pkhTransaction

        XCTAssertEqual(syncer.shouldRequestTransaction(hash: transaction.dataHash), true)
    }

    func testShouldRequest_BlockExists() {
        let block = TestData.firstBlock

        try! realm.write {
            realm.add(block)
        }

        XCTAssertEqual(syncer.shouldRequestBlock(hash: block.headerHash), false)
    }

    func testShouldRequest_BlockDoesntExists() {
        let block = TestData.firstBlock

        XCTAssertEqual(syncer.shouldRequestBlock(hash: block.headerHash), true)
    }

}
