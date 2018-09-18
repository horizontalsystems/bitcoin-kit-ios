import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class HeaderSyncerTests: XCTestCase {

    private var headerSyncer: HeaderSyncer!

    private var realm: Realm!
    private var checkpointBlock: Block!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        realm = mockWalletKit.realm

        checkpointBlock = TestData.checkpointBlock

        let mockNetwork = mockWalletKit.mockNetwork
        stub(mockNetwork) { mock in
            when(mock.checkpointBlock.get).thenReturn(checkpointBlock)
        }

        headerSyncer = HeaderSyncer(realmFactory: mockWalletKit.mockRealmFactory, network: mockNetwork, hashCheckpointThreshold: 3)
    }

    override func tearDown() {
        headerSyncer = nil

        realm = nil
        checkpointBlock = nil

        super.tearDown()
    }

    func testSync_NoBlocksInRealm() {
        XCTAssertEqual(headerSyncer.getHeaders(), [checkpointBlock.headerHash])
    }

    func testSync_NoBlocksInChain() {
        try! realm.write {
            realm.add(TestData.oldBlock)
        }

        XCTAssertEqual(headerSyncer.getHeaders(), [checkpointBlock.headerHash])
    }

    func testSync_SingleBlockInChain() {
        let firstBlock = TestData.firstBlock

        try! realm.write {
            realm.add(firstBlock)
        }

        XCTAssertEqual(headerSyncer.getHeaders(), [firstBlock.headerHash, checkpointBlock.headerHash])
    }

    func testSync_SeveralBlocksInChain() {
        let thirdBlock = TestData.thirdBlock

        try! realm.write {
            realm.add(thirdBlock)
        }

        XCTAssertEqual(headerSyncer.getHeaders(), [thirdBlock.headerHash, checkpointBlock.headerHash])
    }

    func testSync_MoreThanThreshold() {
        let forthBlock = TestData.forthBlock
        let firstBlock = forthBlock.previousBlock!.previousBlock!.previousBlock!

        try! realm.write {
            realm.add(forthBlock)
        }

        XCTAssertEqual(headerSyncer.getHeaders(), [forthBlock.headerHash, firstBlock.headerHash])
    }

}
