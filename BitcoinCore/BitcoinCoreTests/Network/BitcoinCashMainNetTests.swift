//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class BitcoinCashMainNetTests: XCTestCase {
//
//    private var mockNetwork: BitcoinCashMainNet!
//    private var mockValidatorHelper: MockValidatorHelper!
//    private var mockBlockHelper: MockIBlockHelper!
//    private var mockMerkleBranch: MockIMerkleBranch!
//
//    override func setUp() {
//        super.setUp()
//
//        mockValidatorHelper = MockValidatorHelper()
//        mockMerkleBranch = MockIMerkleBranch()
//
//        mockBlockHelper = MockIBlockHelper()
//        stub(mockBlockHelper) { mock in
//            when(mock.medianTimePast(block: any())).thenReturn(0)
//            when(mock.previous(for: any(), index: any())).thenReturn(TestData.checkpointBlock)
//        }
//        mockNetwork = BitcoinCashMainNet(validatorFactory: mockValidatorHelper.mockFactory, blockHelper: mockBlockHelper, merkleBranch: mockMerkleBranch)
//    }
//
//    override func tearDown() {
//        mockNetwork = nil
//        mockValidatorHelper = nil
//        mockBlockHelper = nil
//
//        super.tearDown()
//    }
//
//    func testValidateLegacyDifficultyTransition() {
//        let block = TestData.firstBlock
//        block.height = 4032
//        do {
//            try mockNetwork.validate(block: block, previousBlock: TestData.checkpointBlock)
//            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockLegacyValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockEDAValidator, never()).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockDAAValidator, never()).validate(candidate: any(), block: any(), network: any())
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//    func testValidateLegacyBits() {
//        let block = TestData.firstBlock
//        do {
//            try mockNetwork.validate(block: block, previousBlock: TestData.checkpointBlock)
//            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockEDAValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockDAAValidator, never()).validate(candidate: any(), block: any(), network: any())
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//    func testValidateDAABits() {
//        stub(mockBlockHelper) { mock in
//            when(mock.medianTimePast(block: any())).thenReturn(1510600000)
//        }
//        let block = TestData.firstBlock
//        do {
//            try mockNetwork.validate(block: block, previousBlock: TestData.checkpointBlock)
//            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockLegacyValidator, never()).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockEDAValidator, never()).validate(candidate: any(), block: any(), network: any())
//            verify(mockValidatorHelper.mockDAAValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//}
