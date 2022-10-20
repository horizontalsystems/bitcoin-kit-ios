import XCTest
import Cuckoo
import BigInt
@testable import DashKit
@testable import BitcoinCore

class DarkGravityWaveTestNetValidatorTests: XCTestCase {

    private var validator: DarkGravityWaveTestNetValidator!
    private var mockDifficultyEncoder: MockIDashDifficultyEncoder!

    private var block: Block!
    private var previousBlock: Block!

    override func setUp() {
        super.setUp()

        mockDifficultyEncoder = MockIDashDifficultyEncoder()

        validator = DarkGravityWaveTestNetValidator(difficultyEncoder: mockDifficultyEncoder, targetSpacing: 150, targetTimeSpan: 3600, maxTargetBits: 0x1e0fffff)

        block = Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: Data(),
                        previousBlockHeaderHash: Data(),
                        merkleRoot: Data(),
                        timestamp: 10000,
                        bits: 0x1e0fffff,
                        nonce: 1
                ),
                height: 123457)

        previousBlock = Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: Data(),
                        previousBlockHeaderHash: Data(),
                        merkleRoot: Data(),
                        timestamp: 10000 - 2 * 3600 - 1,
                        bits: 0x1b1441aa,
                        nonce: 1
                ),
                height: 123456)
    }

    override func tearDown() {
        validator = nil

        block = nil
        previousBlock = nil

        super.tearDown()
    }

    func testIsValidatable() {
        XCTAssertEqual(validator.isBlockValidatable(block: block, previousBlock: previousBlock), true)
    }

    func testNotIsValidatable() {
        block.timestamp = previousBlock.timestamp + 1
        XCTAssertEqual(validator.isBlockValidatable(block: block, previousBlock: previousBlock), false)
    }

    func testValidateMaxTarget() {
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateChangeTarget() {
        block.bits = 999
        block.timestamp = previousBlock.timestamp + 4 * 150 + 1
        stub(mockDifficultyEncoder) { mock in
            when(mock.decodeCompact(bits: equal(to: previousBlock.bits))).thenReturn(BigInt(1))
            when(mock.encodeCompact(from: equal(to: BigInt(10)))).thenReturn(999)
        }
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
