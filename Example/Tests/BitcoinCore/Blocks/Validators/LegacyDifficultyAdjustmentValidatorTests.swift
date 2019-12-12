import XCTest
import Cuckoo
import BigInt
@testable import BitcoinCore

class LegacyDifficultyAdjustmentValidatorTests: XCTestCase {

    private var validator: LegacyDifficultyAdjustmentValidator!
    private var mockNetwork: MockINetwork!
    private var mockEncoder: MockIDifficultyEncoder!
    private var mockBlockHelper: MockIBlockValidatorHelper!

    private var checkPointBlock: Block!
    private var previousBlock: Block!
    private var block: Block!

    override func setUp() {
        super.setUp()

        mockNetwork = MockINetwork()
        mockEncoder = MockIDifficultyEncoder()
        stub(mockEncoder) { mock in
            when(mock.decodeCompact(bits: 476399191)).thenReturn(BigInt("10665477591887247494381404907447500979192021944764506987270680608768"))
            when(mock.decodeCompact(bits: 474199013)).thenReturn(BigInt("7129927859545590787920041835044506526699926406309469412482969763840"))
            when(mock.encodeCompact(from: equal(to: BigInt("7129928201274994723790235748908587989251132236328748923672922318604")))).thenReturn(474199013)
        }
        mockBlockHelper = MockIBlockValidatorHelper()

        validator = LegacyDifficultyAdjustmentValidator(encoder: mockEncoder, blockValidatorHelper: mockBlockHelper, heightInterval: 2016, targetTimespan: 1209600, maxTargetBits: 0x1d00ffff)

        checkPointBlock = TestData.checkpointBlock
        checkPointBlock.height = 40320
        checkPointBlock.bits = 476399191
        checkPointBlock.timestamp = 1266169979

        previousBlock = TestData.firstBlock
        previousBlock.height = 40320 + 2015
        previousBlock.bits = 476399191
        previousBlock.timestamp = 1266978603

        block = TestData.secondBlock
        block.height = 40320 + 2016
        block.bits = 474199013
        block.timestamp = 1266979264

        stub(mockBlockHelper) { mock in
            when(mock.previous(for: any(), count: any())).thenReturn(checkPointBlock)
        }
    }

    override func tearDown() {
        validator = nil
        mockNetwork = nil

        checkPointBlock = nil
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

    func testNoPreviousBlock() {
        stub(mockBlockHelper) { mock in
            when(mock.previous(for: any(), count: any())).thenReturn(nil)
        }
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("noHeader exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.noPreviousBlock)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNotDifficultyTransitionEqualBits() {
        stub(mockEncoder) { mock in
            when(mock.encodeCompact(from: equal(to: BigInt("7129928201274994723790235748908587989251132236328748923672922318604")))).thenReturn(0)
        }
        do {
            try validator.validate(block: block, previousBlock: previousBlock)
            XCTFail("noHeader exception not thrown")
        } catch let error as BitcoinCoreErrors.BlockValidation {
            XCTAssertEqual(error, BitcoinCoreErrors.BlockValidation.notDifficultyTransitionEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
