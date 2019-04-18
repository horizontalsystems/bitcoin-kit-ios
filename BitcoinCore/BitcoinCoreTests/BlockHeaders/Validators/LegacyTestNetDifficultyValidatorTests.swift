import XCTest
import Cuckoo
import BigInt
@testable import BitcoinCore

class LegacyTestNetDifficultyValidatorTests: XCTestCase {
    let maxDifficulty = 0x1d00ffff
    let targetSpacing = 600
    let heightInterval = 2016

    private var validator: LegacyTestNetDifficultyValidator!
    private var mockBlockHelper: MockIBlockValidatorHelper!

    private var checkPointBlock: Block!
    private var previousBlock: Block!
    private var block: Block!

    override func setUp() {
        super.setUp()

        mockBlockHelper = MockIBlockValidatorHelper()

        block = TestData.secondBlock
        block.height = 40320 + heightInterval
        block.bits = 474199013
        block.timestamp = 1266979264

        previousBlock = TestData.firstBlock
        previousBlock.height = 40320 + heightInterval - 1
        previousBlock.bits = 476399191
        previousBlock.timestamp = 1266978603

        checkPointBlock = TestData.checkpointBlock
        checkPointBlock.height = 40320
        checkPointBlock.bits = 476399191
        checkPointBlock.timestamp = 1266169979

        stub(mockBlockHelper) { mock in
            when(mock.previous(for: equal(to: block), count: 1)).thenReturn(previousBlock)
        }

        validator = LegacyTestNetDifficultyValidator(blockHelper: mockBlockHelper, heightInterval: heightInterval, targetSpacing: targetSpacing, maxTargetBits: maxDifficulty)
    }

    override func tearDown() {
        validator = nil
        mockBlockHelper = nil

        checkPointBlock = nil
        previousBlock = nil
        block = nil

        super.tearDown()
    }

    func testValidate() {
        previousBlock.bits = 474199013
        previousBlock.timestamp = block.timestamp - targetSpacing

        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateBigGap() {
        previousBlock.bits = 17
        previousBlock.timestamp = block.timestamp - targetSpacing * 3

        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateCheckpointDifficulty() {
        // check skip blocks with maximum difficulty and stop on checkpoint block. EqualVerify bits from checkpoint
        stub(mockBlockHelper) { mock in
            when(mock.previous(for: equal(to: previousBlock), count: 1)).thenReturn(checkPointBlock)
        }

        checkPointBlock.bits = maxDifficulty
        previousBlock.bits = maxDifficulty
        block.bits = maxDifficulty

        previousBlock.height = checkPointBlock.height + 1
        block.height = previousBlock.height + 1

        checkPointBlock.timestamp = block.timestamp - targetSpacing * 2
        previousBlock.timestamp = block.timestamp - targetSpacing

        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }

        checkPointBlock.bits = 17
        block.bits = 17

        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNoPreviousBlock() {
        previousBlock.bits = maxDifficulty
        stub(mockBlockHelper) { mock in
            when(mock.previous(for: equal(to: previousBlock), count: 1)).thenReturn(nil)
        }

        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("noHeader exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNotDifficultyTransitionEqualBits() {
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("noHeader exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
