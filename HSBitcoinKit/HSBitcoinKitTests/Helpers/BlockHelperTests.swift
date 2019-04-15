import XCTest
import Cuckoo
@testable import HSBitcoinKit

class BlockHelperTests: XCTestCase {
    private var mockStorage: MockIStorage!
    private var blockHelper: BlockHelper!
    private var firstBlock: Block!

    override func setUp() {
        super.setUp()
        mockStorage = MockIStorage()

        stub(mockStorage) { mock in
            when(mock.block(byHashHex: TestData.checkpointBlock.previousBlockHashReversedHex)).thenReturn(nil)
            when(mock.block(byHashHex: TestData.checkpointBlock.headerHashReversedHex)).thenReturn(TestData.checkpointBlock)
            when(mock.block(byHashHex: TestData.firstBlock.headerHashReversedHex)).thenReturn(TestData.firstBlock)
            when(mock.block(byHashHex: TestData.secondBlock.headerHashReversedHex)).thenReturn(TestData.secondBlock)
            when(mock.block(byHashHex: TestData.thirdBlock.headerHashReversedHex)).thenReturn(TestData.thirdBlock)
        }

        firstBlock = TestData.thirdBlock
        firstBlock.timestamp = 1000

        blockHelper = BlockHelper(storage: mockStorage)
    }

    override func tearDown() {
        mockStorage = nil
        blockHelper = nil
        firstBlock = nil

        super.tearDown()
    }

    func testPrevious() {
        let block = TestData.thirdBlock

        XCTAssertEqual(blockHelper.previous(for: block, count: 1)?.headerHashReversedHex, TestData.secondBlock.headerHashReversedHex)
        XCTAssertNil(blockHelper.previous(for: block, count: 4))
    }

    func testPreviousWindow() {
        let block = TestData.secondBlock

        XCTAssertEqual(blockHelper.previousWindow(for: block, count: 2)?.map { $0.headerHashReversedHex }, [TestData.checkpointBlock.headerHashReversedHex, TestData.firstBlock.headerHashReversedHex])
        XCTAssertNil(blockHelper.previousWindow(for: block, count: 3))
    }

    func testWrongPrevious() {
        let block = TestData.checkpointBlock

        XCTAssertNil(blockHelper.previous(for: block, count: 1))
    }

    func testMedianTimePast() {
        let block = chain(from: firstBlock, length: 11)

        do {
            let medianTime = try blockHelper.medianTimePast(block: block)
            XCTAssertEqual(medianTime, 1600)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testMedianTimePastFor3() {
        stub(mockStorage) { mock in
            when(mock.block(byHashHex: firstBlock.previousBlockHashReversedHex)).thenReturn(nil)
        }
        let block = chain(from: firstBlock, length: 2)

        do {
            let medianTime = try blockHelper.medianTimePast(block: block)
            XCTAssertEqual(medianTime, 1100)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    private func chain(from firstBlock: Block, length: Int, timeInterval: Int = 100) -> Block {
        var currentBlock = firstBlock

        stub(mockStorage) { mock in
            for _ in 0..<length {
                let header = BlockHeader(version: 0, headerHash: Data(), previousBlockHeaderHash: Data(from: currentBlock.timestamp + timeInterval),
                        merkleRoot: Data(), timestamp: currentBlock.timestamp + timeInterval, bits: 0, nonce: 0)
                let block = Block(withHeader: header, previousBlock: currentBlock)

                currentBlock.setHeaderHash(hash: block.previousBlockHashReversedHex.reversedData!)
                when(mock.block(byHashHex: currentBlock.headerHashReversedHex)).thenReturn(currentBlock)

                currentBlock = block
            }
        }

        return currentBlock
    }

}
