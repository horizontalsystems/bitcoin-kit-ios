import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class HeaderHandlerTests: XCTestCase {

    private var mockValidatedBlockFactory: MockValidatedBlockFactory!
    private var mockPeerGroup: MockPeerGroup!
    private var headerHandler: HeaderHandler!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockValidatedBlockFactory = mockWalletKit.mockValidatedBlockFactory
        mockPeerGroup = mockWalletKit.mockPeerGroup
        realm = mockWalletKit.realm

        stub(mockPeerGroup) { mock in
            when(mock.syncBlocks(hashes: any())).thenDoNothing()
        }

        headerHandler = HeaderHandler(realmFactory: mockWalletKit.mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, peerGroup: mockPeerGroup)
    }

    override func tearDown() {
        mockValidatedBlockFactory = nil
        mockPeerGroup = nil
        headerHandler = nil

        realm = nil

        super.tearDown()
    }

    func testHandle_EmptyHeaders() {
        var caught = false

        do {
            try headerHandler.handle(headers: [])
        } catch let error as HeaderHandler.HandleError {
            caught = true
            XCTAssertEqual(error, HeaderHandler.HandleError.emptyHeaders)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "emptyHeaders exception not thrown")
    }

    func testValidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenReturn(firstBlock)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenReturn(secondBlock)
        }

        try! headerHandler.handle(headers: [firstBlock.header!, secondBlock.header!])

        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)

        verify(mockPeerGroup).syncBlocks(hashes: equal(to: [firstBlock.headerHash, secondBlock.headerHash]))
    }

    func testInvalidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenThrow(BlockValidatorError.notEqualBits)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenReturn(secondBlock)
        }

        var caught = false

        do {
            try headerHandler.handle(headers: [firstBlock.header!, secondBlock.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "validation exception not thrown")

        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)

        verify(mockPeerGroup, never()).syncBlocks(hashes: any())
    }

    func testPartialValidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenReturn(firstBlock)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenThrow(BlockValidatorError.notEqualBits)
        }

        var caught = false

        do {
            try headerHandler.handle(headers: [firstBlock.header!, secondBlock.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "validation exception not thrown")

        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)

        verify(mockPeerGroup).syncBlocks(hashes: equal(to: [firstBlock.headerHash]))
    }

}
