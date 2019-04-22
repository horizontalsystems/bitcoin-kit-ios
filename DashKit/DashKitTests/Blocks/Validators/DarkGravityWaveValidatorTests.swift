import XCTest
import Cuckoo
@testable import DashKit
@testable import BitcoinCore

class DarkGravityWaveValidatorTests: XCTestCase {
    private let bitsArray = [0x1b104be1, 0x1b10e09e, 0x1b11a33c, 0x1b121cf3, 0x1b11951e, 0x1b11abac, 0x1b118d9c, 0x1b1123f9, 0x1b1141bf, 0x1b110764,
                             0x1b107556, 0x1b104297, 0x1b1063d0, 0x1b10e878, 0x1b0dfaff, 0x1b0c9ab8, 0x1b0c03d6, 0x1b0dd168, 0x1b10b864, 0x1b0fed89,
                             0x1b113ff1, 0x1b10460b, 0x1b13b83f, 0x1b1418d4]

    private let timestampArray = [1408728124, 1408728332, 1408728479, 1408728495, 1408728608, 1408728744, 1408728756, 1408728950, 1408729116, 1408729179,
                                  1408729305, 1408729474, 1408729576, 1408729587, 1408729647, 1408729678, 1408730179, 1408730862, 1408730914, 1408731242,
                                  1408731256, 1408732229, 1408732257, 1408732489] // 123433 - 123456

    private var validator: DarkGravityWaveValidator!
    private var mockBlockHelper: MockIDashBlockValidatorHelper!

    private var blocks = [Block]()

    override func setUp() {
        super.setUp()
        mockBlockHelper = MockIDashBlockValidatorHelper()

        validator = DarkGravityWaveValidator(encoder: DifficultyEncoder(), blockHelper: mockBlockHelper, heightInterval: 24, targetTimeSpan: 3600, maxTargetBits: 0x1e0fffff, firstCheckpointHeight: 123432)

        blocks.append(Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: Data(),
                        previousBlockHeaderHash: Data(),
                        merkleRoot: Data(),
                        timestamp: 1408732505,
                        bits: 0x1b1441de,
                        nonce: 1
                ),
                height: 123457))

        for i in 0..<24 {
            let block = Block(
                    withHeader: BlockHeader(version: 1, headerHash: Data(from: i), previousBlockHeaderHash: Data(from: i), merkleRoot: Data(), timestamp: timestampArray[timestampArray.count - i - 1], bits: bitsArray[bitsArray.count - i - 1], nonce: 0),
                    height: blocks[0].height - i - 1
            )
            blocks.append(block)
        }
        stub(mockBlockHelper) { mock in
            for i in 0..<24 {
                when(mock.previous(for: equal(to: blocks[i]), count: 1)).thenReturn(blocks[i + 1])
            }
        }
    }

    override func tearDown() {
        validator = nil
        mockBlockHelper = nil

        blocks.removeAll()

        super.tearDown()
    }

    func testValidate() {
        do {
            try validator.validate(block: blocks[0], previousBlock: blocks[1])
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testTrust() {
        do {
            try validator.validate(block: blocks[1], previousBlock: blocks[2])
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
