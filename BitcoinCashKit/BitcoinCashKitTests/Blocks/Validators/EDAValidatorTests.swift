import XCTest
import Cuckoo
@testable import BitcoinCashKit
@testable import BitcoinCore

class EDAValidatorTests: XCTestCase {

    private var validator: EDAValidator!
    private var mockDifficultyEncoder: MockIBitcoinCashDifficultyEncoder!
    private var mockBlockHelper: MockIBitcoinCashBlockValidatorHelper!

    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()

        mockDifficultyEncoder = MockIBitcoinCashDifficultyEncoder()
        mockBlockHelper = MockIBitcoinCashBlockValidatorHelper()

        validator = EDAValidator(encoder: mockDifficultyEncoder, blockHelper: mockBlockHelper, maxTargetBits: 0x1d00ffff, firstCheckpointHeight: 0)

        block = TestData.firstBlock
        candidate = TestData.secondBlock
    }

    override func tearDown() {
        validator = nil
        mockDifficultyEncoder = nil
        mockBlockHelper = nil

        block = nil
        candidate = nil

        super.tearDown()
    }

    func testIgnoreFirstBlocks() {
        // we must ignore all blocks before firstCheckpoint + 6
        let ignoredPreviousBlock = Block(withHeader: BlockHeader(
                version: 1,
                headerHash: "11b10ccc".reversedData!,
                previousBlockHeaderHash: Data(repeating: 0x01, count: 2),
                merkleRoot: Data(),
                timestamp: 1337966314,
                bits: 386604799,
                nonce: 1716024842
        ), height: 5)
        do {
            try validator.validate(block: block, previousBlock: ignoredPreviousBlock)
            verifyNoMoreInteractions(mockBlockHelper)
            verifyNoMoreInteractions(mockDifficultyEncoder)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }
    func testValidate() {
        do {
            try validator.validate(block: candidate, previousBlock: block)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNotEqualBits() {
        candidate = Block(withHeader: BlockHeader(version: candidate.version, headerHash: candidate.headerHash,
                previousBlockHeaderHash: candidate.previousBlockHash,
                merkleRoot: candidate.merkleRoot, timestamp: candidate.timestamp, bits: 3, nonce: 0),
                height: candidate.height)
        do {
            try validator.validate(block: candidate, previousBlock: block)
            XCTFail("notEqualBits exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
