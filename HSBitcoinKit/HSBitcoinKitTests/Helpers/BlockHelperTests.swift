import XCTest
import Cuckoo
@testable import HSBitcoinKit

class BlockHelperTests: XCTestCase {
    private var blockHelper: BlockHelper!
    private var firstBlock: Block!

    override func setUp() {
        super.setUp()
        blockHelper = BlockHelper()

        firstBlock = TestData.thirdBlock
        firstBlock.header?.timestamp = 1000
    }

    override func tearDown() {
        blockHelper = nil
        firstBlock = nil

        super.tearDown()
    }

    func testPrevious() {
        let block = TestData.thirdBlock

        XCTAssertEqual(blockHelper.previous(for: block, index: 1)?.reversedHeaderHashHex, TestData.secondBlock.reversedHeaderHashHex)
        XCTAssertEqual(blockHelper.previous(for: block, index: 4), nil)
    }

    func testPreviousWindow() {
        let block = TestData.secondBlock

        XCTAssertEqual(blockHelper.previousWindow(for: block, count: 2)?.map { $0.reversedHeaderHashHex }, [TestData.checkpointBlock.reversedHeaderHashHex, TestData.firstBlock.reversedHeaderHashHex])
        XCTAssertEqual(blockHelper.previousWindow(for: block, count: 3), nil)
    }

    func testWrongPrevious() {
        let block = TestData.checkpointBlock

        XCTAssertEqual(blockHelper.previous(for: block, index: 1), nil)
    }

    func chain(from firstBlock: Block, length: Int, timeInterval: Int = 100) -> Block {
        var currentBlock = firstBlock
        for _ in 0..<length {
            let header = BlockHeader()
            header.timestamp = (currentBlock.header?.timestamp ?? 0) + timeInterval
            let block = Block(withHeader: header, previousBlock: currentBlock)

            currentBlock = block
        }
        return currentBlock
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
        firstBlock.previousBlock = nil
        let block = chain(from: firstBlock, length: 2)

        do {
            let medianTime = try blockHelper.medianTimePast(block: block)
            XCTAssertEqual(medianTime, 1100)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNoHeader() {
        let block = chain(from: firstBlock, length: 11)
        block.previousBlock?.header = nil

        do {
            let _ = try blockHelper.medianTimePast(block: block)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
