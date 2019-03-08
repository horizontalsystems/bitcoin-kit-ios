import XCTest
import Cuckoo
@testable import HSBitcoinKit

class DarkGravityWaveValidatorTests: XCTestCase {
    private let bitsArray = [0x1b104be1, 0x1b10e09e, 0x1b11a33c, 0x1b121cf3, 0x1b11951e, 0x1b11abac, 0x1b118d9c, 0x1b1123f9, 0x1b1141bf, 0x1b110764,
                             0x1b107556, 0x1b104297, 0x1b1063d0, 0x1b10e878, 0x1b0dfaff, 0x1b0c9ab8, 0x1b0c03d6, 0x1b0dd168, 0x1b10b864, 0x1b0fed89,
                             0x1b113ff1, 0x1b10460b, 0x1b13b83f, 0x1b1418d4]

    private let timestampArray = [1408728124, 1408728332, 1408728479, 1408728495, 1408728608, 1408728744, 1408728756, 1408728950, 1408729116, 1408729179,
                                  1408729305, 1408729474, 1408729576, 1408729587, 1408729647, 1408729678, 1408730179, 1408730862, 1408730914, 1408731242,
                                  1408731256, 1408732229, 1408732257, 1408732489] // 123433 - 123456

    private var validator: DarkGravityWaveValidator!
    private var network: MockINetwork!

    private var candidate: Block!

    override func setUp() {
        super.setUp()

        validator = DarkGravityWaveValidator(encoder: DifficultyEncoder(), blockHelper: BlockHelper())
        network = MockINetwork()
        stub(network) { mock in
            when(mock.heightInterval.get).thenReturn(24)
            when(mock.targetTimeSpan.get).thenReturn(3600)
            when(mock.maxTargetBits.get).thenReturn(0x1e0fffff)
            when(mock.targetSpacing.get).thenReturn(150)
        }

        candidate = Block(
                withHeader: BlockHeader(
                        version: 1,
                        headerHash: "".reversedData,
                        previousBlockHeaderReversedHex: "",
                        merkleRootReversedHex: "",
                        timestamp: 1408732505,
                        bits: 0x1b1441de,
                        nonce: 1
                ),
                height: 123457)
    }

    override func tearDown() {
        validator = nil
        network = nil

        candidate = nil

        super.tearDown()
    }

    // MAKE real test data from bitcoin cash mainnet
    func makeBlocks() {
        var lastBlock = candidate
        for i in 0..<24 {
            let block = Block(
                    withHeader: BlockHeader(version: 1, headerHash: "".reversedData, previousBlockHeaderReversedHex: "", merkleRootReversedHex: "", timestamp: timestampArray[timestampArray.count - i - 1], bits: bitsArray[bitsArray.count - i - 1], nonce: 0),
                    height: candidate.height - i - 1
            )
            lastBlock?.previousBlock = block
            lastBlock = block
        }
    }

    func testValidate() {
        makeBlocks()
        do {
            try validator.validate(candidate: candidate, block: candidate.previousBlock!, network: network)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
