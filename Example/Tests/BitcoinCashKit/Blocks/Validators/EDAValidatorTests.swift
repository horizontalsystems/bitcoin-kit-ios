import XCTest
import Cuckoo
@testable import BitcoinCashKit
@testable import BitcoinCore

class EDAValidatorTests: XCTestCase {

    private var validator: EDAValidator!
    private var mockDifficultyEncoder: MockIBitcoinCashDifficultyEncoder!
    private var mockBlockHelper: MockIBitcoinCashBlockValidatorHelper!
    private var mockMedianTimeHelper: MockIBitcoinCashBlockMedianTimeHelper!

    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()

        mockDifficultyEncoder = MockIBitcoinCashDifficultyEncoder()
        mockBlockHelper = MockIBitcoinCashBlockValidatorHelper()
        mockMedianTimeHelper = MockIBitcoinCashBlockMedianTimeHelper()

        validator = EDAValidator(encoder: mockDifficultyEncoder, blockHelper: mockBlockHelper, blockMedianTimeHelper: mockMedianTimeHelper, maxTargetBits: 0x1d00ffff)

        block = TestData.firstBlock
        candidate = TestData.secondBlock
    }

    override func tearDown() {
        validator = nil
        mockDifficultyEncoder = nil
        mockBlockHelper = nil
        mockMedianTimeHelper = nil

        block = nil
        candidate = nil

        super.tearDown()
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
