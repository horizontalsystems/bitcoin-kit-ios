import XCTest
import Cuckoo
@testable import BitcoinCore

class BitsValidatorTests: XCTestCase {

    private var validator: BitsValidator!
    private var network: MockINetwork!

    private var previousBlock: Block!
    private var block: Block!

    override func setUp() {
        super.setUp()
        validator = BitsValidator()
        network = MockINetwork()

        previousBlock = TestData.firstBlock
        block = TestData.secondBlock
    }

    override func tearDown() {
        validator = nil
        network = nil

        previousBlock = nil
        block = nil

        super.tearDown()
    }

    func testValidate() {
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNotEqualBits() {
        block.bits = 3
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("notEqualBits exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
