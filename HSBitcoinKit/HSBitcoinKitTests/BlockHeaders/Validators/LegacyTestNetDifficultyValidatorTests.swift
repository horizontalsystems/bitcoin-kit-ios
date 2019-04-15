//import XCTest
//import Cuckoo
//import BigInt
//@testable import HSBitcoinKit
//
//class LegacyTestNetDifficultyValidatorTests: XCTestCase {
//    let maxDifficulty = 0x1d00ffff
//    let targetSpacing = 600
//    let heightInterval = 2016
//
//    private var validator: LegacyTestNetDifficultyValidator!
//    private var mockNetwork: MockINetwork!
//    private var mockStorage: MockIStorage!
//
//    private var checkPointBlock: Block!
//    private var block: Block!
//    private var candidate: Block!
//
//    override func setUp() {
//        super.setUp()
//
//        mockNetwork = MockINetwork()
//        mockStorage = MockIStorage()
//
//        candidate = TestData.secondBlock
//        candidate.height = 40320 + heightInterval
//        candidate.bits = 474199013
//        candidate.timestamp = 1266979264
//
//        block = TestData.firstBlock
//        block.height = 40320 + heightInterval - 1
//        block.bits = 476399191
//        block.timestamp = 1266978603
//
//        checkPointBlock = TestData.checkpointBlock
//        checkPointBlock.height = 40320
//        checkPointBlock.bits = 476399191
//        checkPointBlock.timestamp = 1266169979
//
//        stub(mockNetwork) { mock in
//            when(mock.heightInterval.get).thenReturn(heightInterval)
//            when(mock.targetTimeSpan.get).thenReturn(targetSpacing * heightInterval)
//            when(mock.maxTargetBits.get).thenReturn(maxDifficulty)
//            when(mock.targetSpacing.get).thenReturn(targetSpacing)
//        }
//        stub(mockStorage) { mock in
//            when(mock.block(byHashHex: candidate.previousBlockHashReversedHex)).thenReturn(block)
//        }
//
//        validator = LegacyTestNetDifficultyValidator(storage: mockStorage)
//    }
//
//    override func tearDown() {
//        validator = nil
//        mockNetwork = nil
//        mockStorage = nil
//
//        checkPointBlock = nil
//        block = nil
//        candidate = nil
//
//        super.tearDown()
//    }
//
//    func testValidate() {
//        block.bits = 474199013
//        block.timestamp = candidate.timestamp - targetSpacing
//
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//    func testValidateBigGap() {
//        block.bits = 17
//        block.timestamp = candidate.timestamp - targetSpacing * 3
//
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//    func testValidateCheckpointDifficulty() {
//        // check skip blocks with maximum difficulty and stop on checkpoint block. EqualVerify bits from checkpoint
//        stub(mockStorage) { mock in
//            when(mock.block(byHashHex: block.previousBlockHashReversedHex)).thenReturn(checkPointBlock)
//        }
//
//        checkPointBlock.bits = maxDifficulty
//        block.bits = maxDifficulty
//        candidate.bits = maxDifficulty
//
//        block.height = checkPointBlock.height + 1
//        candidate.height = block.height + 1
//
//        checkPointBlock.timestamp = candidate.timestamp - targetSpacing * 2
//        block.timestamp = candidate.timestamp - targetSpacing
//
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//
//        checkPointBlock.bits = 17
//        candidate.bits = 17
//
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//    func testNoPreviousBlock() {
//        block.bits = maxDifficulty
//        stub(mockStorage) { mock in
//            when(mock.block(byHashHex: block.previousBlockHashReversedHex)).thenReturn(nil)
//        }
//
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//            XCTFail("noHeader exception not thrown")
//        } catch let error as BlockValidatorError {
//            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
//        } catch {
//            XCTFail("Unknown exception thrown")
//        }
//    }
//
//    func testNotDifficultyTransitionEqualBits() {
//        do {
//            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
//            XCTFail("noHeader exception not thrown")
//        } catch let error as BlockValidatorError {
//            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
//        } catch {
//            XCTFail("Unknown exception thrown")
//        }
//    }
//
//}
