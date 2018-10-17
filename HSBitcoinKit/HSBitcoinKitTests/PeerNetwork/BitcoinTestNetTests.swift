import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class BitcoinTestNetTests:XCTestCase {

    private var mockNetwork: BitcoinTestNet!
    private var mockValidatorHelper: MockValidatorHelper!

    override func setUp() {
        super.setUp()

        let mockBitcoinKit = MockBitcoinKit()
        mockValidatorHelper = MockValidatorHelper(mockBitcoinKit: mockBitcoinKit)

        mockNetwork = BitcoinTestNet(validatorFactory: mockValidatorHelper.mockFactory)
    }

    override func tearDown() {
        mockNetwork = nil
        mockValidatorHelper = nil

        super.tearDown()
    }

    func testValidateLegacyDifficultyTransition() {
        let block = TestData.firstBlock
        block.height = 4032
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyTestNetValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockBitsValidator, never()).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateTestNet() {
        let block = TestData.firstBlock
        block.previousBlock?.header!.timestamp = 1329264000 + 1
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyTestNetValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockBitsValidator, never()).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateOldBits() {
        let block = TestData.firstBlock
        block.previousBlock?.header!.timestamp = 0
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyTestNetValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockBitsValidator, times(1)).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
