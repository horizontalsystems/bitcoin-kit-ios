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

    func testForkHandling_NewLeafHigher() {
        let secondBlock = TestData.secondBlock

        try! realm.write {
            realm.add(secondBlock)
        }

        let newSecond = newBlock(previousBlock: secondBlock.previousBlock!)
        let newThird = newBlock(previousBlock: newSecond)
        let secondBlockReversedHeaderHashHex = secondBlock.reversedHeaderHashHex

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: newSecond.header!), previousBlock: equal(to: secondBlock.previousBlock!))).thenReturn(newSecond)
            when(mock.block(fromHeader: equal(to: newThird.header!), previousBlock: equal(to: newSecond))).thenReturn(newThird)
        }

        try! headerHandler.handle(headers: [secondBlock.previousBlock!.header!, newSecond.header!, newThird.header!])

        verify(mockPeerGroup).syncBlocks(hashes: equal(to: [newSecond, newThird].map{ $0.headerHash }))
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testForkHandling_ExistingLeafHigher() {
        let secondBlock = TestData.secondBlock
        let newSecond = newBlock(previousBlock: secondBlock.previousBlock!)
        let newThird = newBlock(previousBlock: newSecond)
        let secondBlockReversedHeaderHashHex = secondBlock.reversedHeaderHashHex

        try! realm.write {
            realm.add(newThird)
        }

        try! headerHandler.handle(headers: [secondBlock.previousBlock!.header!, newSecond.header!, newThird.header!])

        verify(mockPeerGroup, never()).syncBlocks(hashes: any())
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testForkHandling_RemovalOfOnlyDivergedPart() { // Instead of whole leaf
        let oldSecond = TestData.secondBlock

        try! realm.write {
            realm.add(oldSecond)
        }

        let newSecond = newBlock(previousBlock: oldSecond.previousBlock!)
        let newThird = newBlock(previousBlock: newSecond)
        let newSecondHeader = newSecond.header!
        let newThirdHeader = newThird.header!
        let secondBlockReversedHeaderHashHex = oldSecond.reversedHeaderHashHex
        let oldFirst = oldSecond.previousBlock!
        let oldCheckPoint = oldFirst.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: newSecond.header!), previousBlock: equal(to: oldFirst))).thenReturn(newSecond)
            when(mock.block(fromHeader: equal(to: newThird.header!), previousBlock: equal(to: newSecond))).thenReturn(newThird)
        }

        try! headerHandler.handle(headers: [oldCheckPoint.header!, oldFirst.header!, newSecond.header!, newThird.header!])

        verify(mockPeerGroup).syncBlocks(hashes: equal(to: [newSecond, newThird].map{ $0.headerHash }))
        verify(mockValidatedBlockFactory, never()).block(fromHeader: equal(to: oldCheckPoint.header!), previousBlock: equal(to: nil))
        verify(mockValidatedBlockFactory, never()).block(fromHeader: equal(to: oldFirst.header!), previousBlock: equal(to: oldCheckPoint))
        verify(mockValidatedBlockFactory).block(fromHeader: equal(to: newSecondHeader), previousBlock: equal(to: oldFirst))
        verify(mockValidatedBlockFactory).block(fromHeader: equal(to: newThirdHeader), previousBlock: equal(to: newSecond))
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testForkHandling_NewLeafHigherButInvalid() {
        let oldSecond = TestData.secondBlock

        try! realm.write {
            realm.add(oldSecond)
        }

        let oldFirst = oldSecond.previousBlock!
        let newSecond = newBlock(previousBlock: oldFirst)
        let newThird = newBlock(previousBlock: newSecond)

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: newSecond.header!), previousBlock: equal(to: oldFirst))).thenReturn(newSecond)
            when(mock.block(fromHeader: equal(to: newThird.header!), previousBlock: equal(to: newSecond))).thenThrow(BlockValidatorError.notEqualBits)
        }

        var caught = false

        do {
            try headerHandler.handle(headers: [oldFirst.header!, newSecond.header!, newThird.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        verify(mockPeerGroup, never()).syncBlocks(hashes: any())
        XCTAssertTrue(caught, "validation exception not thrown")
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", oldSecond.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    private func newBlock(previousBlock: Block) -> Block {
        return Block(
                withHeader: BlockHeader(
                        version: 1,
                        previousBlockHeaderReversedHex: "000000000000000000000000000000000000000000000000000000000000000",
                        merkleRootReversedHex: "000000000000000000000000000000000000000000000000000000000000000",
                        timestamp: 1337000000 + previousBlock.height,
                        bits: 486604799,
                        nonce: 627458064
                ),
                previousBlock: previousBlock
        )
    }

}
