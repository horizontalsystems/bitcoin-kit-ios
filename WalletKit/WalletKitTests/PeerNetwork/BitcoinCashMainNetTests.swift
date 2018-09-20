import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class BitcoinCashMainNetTests:XCTestCase {

    private var mockNetwork: BitcoinCashMainNet!
    private var mockValidatorHelper: MockValidatorHelper!
    private var mockBlockHelper: MockBlockHelper!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()
        mockValidatorHelper = MockValidatorHelper(mockWalletKit: mockWalletKit)

        mockBlockHelper = mockWalletKit.mockBlockHelper
        stub(mockBlockHelper) { mock in
            when(mock.medianTimePast(block: any(), count: any())).thenReturn(0)
        }
        mockNetwork = BitcoinCashMainNet(validatorFactory: mockValidatorHelper.mockFactory, blockHelper: mockWalletKit.mockBlockHelper)
    }

    override func tearDown() {
        mockNetwork = nil
        mockValidatorHelper = nil
        mockBlockHelper = nil

        super.tearDown()
    }

    func testValidateLegacyDifficultyTransition() {
        let block = TestData.firstBlock
        block.height = 4032
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockEDAValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockDAAValidator, never()).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateLegacyBits() {
        let block = TestData.firstBlock
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockEDAValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockDAAValidator, never()).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testValidateDAABits() {
        stub(mockBlockHelper) { mock in
            when(mock.medianTimePast(block: any(), count: any())).thenReturn(1510600000)
        }
        let block = TestData.firstBlock
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockEDAValidator, never()).validate(candidate: any(), block: any(), network: any())
            verify(mockValidatorHelper.mockDAAValidator, times(1)).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
