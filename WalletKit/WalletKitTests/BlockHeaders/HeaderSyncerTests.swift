import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class HeaderSyncerTests: XCTestCase {

    private var mockValidatedBlockFactory: MockValidatedBlockFactory!
    private var syncer: HeaderSyncer!

    private var realm: Realm!
    private var checkpointBlock: Block!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockValidatedBlockFactory = mockWalletKit.mockValidatedBlockFactory
        realm = mockWalletKit.realm

        checkpointBlock = TestData.checkpointBlock

        let mockNetwork = mockWalletKit.mockNetwork
        stub(mockNetwork) { mock in
            when(mock.checkpointBlock.get).thenReturn(checkpointBlock)
        }

        syncer = HeaderSyncer(realmFactory: mockWalletKit.mockRealmFactory, validateBlockFactory: mockValidatedBlockFactory, network: mockNetwork, hashCheckpointThreshold: 3)
    }

    override func tearDown() {
        mockValidatedBlockFactory = nil
        syncer = nil

        realm = nil
        checkpointBlock = nil

        super.tearDown()
    }

    func testGetHashes_NoBlocksInRealm() {
        XCTAssertEqual(syncer.getHashes(), [checkpointBlock.headerHash])
    }

    func testGetHashes_NoBlocksInChain() {
        try! realm.write {
            realm.add(TestData.oldBlock)
        }

        XCTAssertEqual(syncer.getHashes(), [checkpointBlock.headerHash])
    }

    func testGetHashes_SingleBlockInChain() {
        let firstBlock = TestData.firstBlock

        try! realm.write {
            realm.add(firstBlock)
        }

        XCTAssertEqual(syncer.getHashes(), [firstBlock.headerHash, checkpointBlock.headerHash])
    }

    func testGetHashes_SeveralBlocksInChain() {
        let thirdBlock = TestData.thirdBlock

        try! realm.write {
            realm.add(thirdBlock)
        }

        XCTAssertEqual(syncer.getHashes(), [thirdBlock.headerHash, checkpointBlock.headerHash])
    }

    func testGetHashes_MoreThanThreshold() {
        let forthBlock = TestData.forthBlock
        let firstBlock = forthBlock.previousBlock!.previousBlock!.previousBlock!

        try! realm.write {
            realm.add(forthBlock)
        }

        XCTAssertEqual(syncer.getHashes(), [forthBlock.headerHash, firstBlock.headerHash])
    }

    func testHandle_ValidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenReturn(firstBlock)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenReturn(secondBlock)
        }

        try! syncer.handle(headers: [firstBlock.header!, secondBlock.header!])

        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)
    }

    func testHandle_InvalidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenThrow(BlockValidatorError.notEqualBits)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenReturn(secondBlock)
        }

        var caught = false

        do {
            try syncer.handle(headers: [firstBlock.header!, secondBlock.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "validation exception not thrown")

        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)
    }

    func testHandle_PartialValidBlocks() {
        let secondBlock = TestData.secondBlock
        let firstBlock = secondBlock.previousBlock!

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: equal(to: firstBlock.header!), previousBlock: equal(to: nil))).thenReturn(firstBlock)
            when(mock.block(fromHeader: equal(to: secondBlock.header!), previousBlock: equal(to: firstBlock))).thenThrow(BlockValidatorError.notEqualBits)
        }

        var caught = false

        do {
            try syncer.handle(headers: [firstBlock.header!, secondBlock.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "validation exception not thrown")

        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", firstBlock.reversedHeaderHashHex).first, nil)
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlock.reversedHeaderHashHex).first, nil)
    }

    func testHandle_ForkHandling_NewLeafHigher() {
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

        try! syncer.handle(headers: [secondBlock.previousBlock!.header!, newSecond.header!, newThird.header!])

        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testHandle_ForkHandling_ExistingLeafHigher() {
        let secondBlock = TestData.secondBlock
        let newSecond = newBlock(previousBlock: secondBlock.previousBlock!)
        let newThird = newBlock(previousBlock: newSecond)
        let secondBlockReversedHeaderHashHex = secondBlock.reversedHeaderHashHex

        try! realm.write {
            realm.add(newThird)
        }

        try! syncer.handle(headers: [secondBlock.previousBlock!.header!, newSecond.header!, newThird.header!])

        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testHandle_ForkHandling_RemovalOfOnlyDivergedPart() { // Instead of whole leaf
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

        try! syncer.handle(headers: [oldCheckPoint.header!, oldFirst.header!, newSecond.header!, newThird.header!])

        verify(mockValidatedBlockFactory, never()).block(fromHeader: equal(to: oldCheckPoint.header!), previousBlock: equal(to: nil))
        verify(mockValidatedBlockFactory, never()).block(fromHeader: equal(to: oldFirst.header!), previousBlock: equal(to: oldCheckPoint))
        verify(mockValidatedBlockFactory).block(fromHeader: equal(to: newSecondHeader), previousBlock: equal(to: oldFirst))
        verify(mockValidatedBlockFactory).block(fromHeader: equal(to: newThirdHeader), previousBlock: equal(to: newSecond))
        XCTAssertEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", secondBlockReversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newSecond.reversedHeaderHashHex).first, nil)
        XCTAssertNotEqual(realm.objects(Block.self).filter("reversedHeaderHashHex = %@", newThird.reversedHeaderHashHex).first, nil)
    }

    func testHandle_ForkHandling_NewLeafHigherButInvalid() {
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
            try syncer.handle(headers: [oldFirst.header!, newSecond.header!, newThird.header!])
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

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
