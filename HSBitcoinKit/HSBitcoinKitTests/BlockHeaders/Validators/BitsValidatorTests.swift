import XCTest
import Cuckoo
@testable import HSBitcoinKit

class BitsValidatorTests: XCTestCase {

    private var validator: BitsValidator!
    private var network: MockINetwork!

    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()
        validator = BitsValidator()
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

    func testNotEqualBits() {
        candidate.bits = 3
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
            XCTFail("notEqualBits exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
