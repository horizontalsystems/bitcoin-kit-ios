import XCTest
import Cuckoo
@testable import HSBitcoinKit
import BigInt

class HeaderValidatorTests: XCTestCase {

    private var validator: HeaderValidator!
    private var network: MockINetwork!

    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()

        validator = HeaderValidator(encoder: DifficultyEncoder())
        network = MockINetwork()

        block = TestData.firstBlock
        candidate = TestData.secondBlock
    }

    override func tearDown() {
        validator = nil
        network = nil

        block = nil
        candidate = nil

        super.tearDown()
    }

    func testValidate() {
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testWrongPreviousHeaderHash() {
        candidate.previousBlockHashReversedHex = Data(hex: "da1a")!.reversedHex
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
            XCTFail("wrongPreviousHeaderHash exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.wrongPreviousHeaderHash)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testWrongProofOfWork_nBitsLessThanHeaderHash() {
        candidate.bits = DifficultyEncoder().encodeCompact(from: BigInt(candidate.headerHashReversedHex, radix: 16)! - 1)
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
            XCTFail("invalidProveOfWork exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.invalidProofOfWork)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
