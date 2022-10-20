import XCTest
import Cuckoo
@testable import BitcoinCore
import BigInt

class ProofOfWorkValidatorTests: XCTestCase {

    private var validator: ProofOfWorkValidator!

    private var previousBlock: Block!
    private var block: Block!

    override func setUp() {
        super.setUp()

        validator = ProofOfWorkValidator(difficultyEncoder: DifficultyEncoder())

        previousBlock = TestData.firstBlock
        block = TestData.secondBlock
    }

    override func tearDown() {
        validator = nil

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

    func testWrongProofOfWork_nBitsLessThanHeaderHash() {
        block.bits = DifficultyEncoder().encodeCompact(from: BigInt(block.headerHash.reversedHex, radix: 16)! - 1)
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("invalidProveOfWork exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.invalidProofOfWork)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
