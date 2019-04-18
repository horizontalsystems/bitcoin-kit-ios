//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class BitcoinMainNetTests:XCTestCase {
//
//    private var mockNetwork: BitcoinMainNet!
//    private var mockValidatorHelper: MockValidatorHelper!
//    private var mockMerkleBranch: MockIMerkleBranch!
//
//    override func setUp() {
//        super.setUp()
//
//        mockValidatorHelper = MockValidatorHelper()
//        mockMerkleBranch = MockIMerkleBranch()
//        mockNetwork = BitcoinMainNet(validatorFactory: mockValidatorHelper.mockFactory, merkleBranch: mockMerkleBranch)
//    }
//
//    override func tearDown() {
//        mockNetwork = nil
//        mockValidatorHelper = nil
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
//            verify(mockValidatorHelper.mockBitsValidator, never()).validate(candidate: any(), block: any(), network: any())
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
//            verify(mockValidatorHelper.mockBitsValidator, times(1)).validate(candidate: any(), block: any(), network: any())
//        } catch let error {
//            XCTFail("\(error) Exception Thrown")
//        }
//    }
//
//}
