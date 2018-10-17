import XCTest
import Cuckoo
@testable import HSBitcoinKit

class HeaderValidatorTests: XCTestCase {

    private var validator: HeaderValidator!
    private var network: MockNetworkProtocol!

    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()

        let mockBitcoinKit = MockBitcoinKit()

        validator = HeaderValidator()
        network = mockBitcoinKit.mockNetwork

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
        candidate.header!.previousBlockHeaderHash = Data(hex: "da1a")!
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
            XCTFail("wrongPreviousHeaderHash exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.wrongPreviousHeaderHash)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNoCandidateHeader() {
        candidate.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: network)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
