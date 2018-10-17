import XCTest
import Cuckoo
import BigInt
@testable import HSBitcoinKit

class LegacyTestNetDifficultyValidatorTests: XCTestCase {
    let maxDifficulty = 0x1d00ffff
    let targetSpacing = 600
    let heightInterval = 2016

    private var validator: LegacyTestNetDifficultyValidator!
    private var mockNetwork: MockNetworkProtocol!

    private var checkPointBlock: Block!
    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()
        let mockBitcoinKit = MockBitcoinKit()
        mockNetwork = mockBitcoinKit.mockNetwork
        stub(mockNetwork) { mock in
            when(mock.heightInterval.get).thenReturn(heightInterval)
            when(mock.targetTimeSpan.get).thenReturn(targetSpacing * heightInterval)
            when(mock.maxTargetBits.get).thenReturn(maxDifficulty)
            when(mock.targetSpacing.get).thenReturn(targetSpacing)
        }
        validator = LegacyTestNetDifficultyValidator()

        candidate = TestData.secondBlock
        candidate.height = 40320 + heightInterval
        candidate.header?.bits = 474199013
        candidate.header?.timestamp = 1266979264

        block = candidate.previousBlock!
        block.height = 40320 + heightInterval - 1
        block.header?.bits = 476399191
        block.header?.timestamp = 1266978603

        checkPointBlock = TestData.checkpointBlock

        checkPointBlock.height = 40320
        checkPointBlock.header?.bits = 476399191
        checkPointBlock.header?.timestamp = 1266169979
    }

    override func tearDown() {
        validator = nil
        mockNetwork = nil

        checkPointBlock = nil
        block = nil
        candidate = nil

        super.tearDown()
    }

    func makeChain(block: Block, lastBlock: Block, interval: Int) {
        var previousBlock: Block = block
        for _ in 0..<interval {
            let block = Block()
            block.height = previousBlock.height - 1
            previousBlock.previousBlock = block

            previousBlock = block
        }
        previousBlock.previousBlock = lastBlock
    }

    func testValidate() {
        block.header!.bits = 474199013
        block.header!.timestamp = candidate.header!.timestamp - targetSpacing

        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateBigGap() {
        block.header!.bits = 17
        block.header!.timestamp = candidate.header!.timestamp - targetSpacing * 3

        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateCheckpointDifficulty() {
        // check skip blocks with maximum difficulty and stop on checkpoint block. EqualVerify bits from checkpoint
        block.previousBlock = checkPointBlock

        checkPointBlock.header?.bits = maxDifficulty
        block.header?.bits = maxDifficulty
        candidate.header?.bits = maxDifficulty

        block.height = checkPointBlock.height + 1
        candidate.height = block.height + 1

        checkPointBlock.header?.timestamp = candidate.header!.timestamp - targetSpacing * 2
        block.header?.timestamp = candidate.header!.timestamp - targetSpacing

        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }

        checkPointBlock.header?.bits = 17
        candidate.header?.bits = 17

        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNoCandidateHeader() {
        candidate.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNoBlockHeader() {
        block.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testCheckPointNoBlockHeader() {
        block.previousBlock = checkPointBlock
        block.header?.bits = maxDifficulty

        checkPointBlock.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNoPreviousBlock() {
        block.header?.bits = maxDifficulty
        block.previousBlock = nil

        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNotDifficultyTransitionEqualBits() {
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
