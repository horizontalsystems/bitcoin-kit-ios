import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class BitcoinRegTestNetTests:XCTestCase {

    private var mockNetwork: BitcoinMainNet!
    private var mockValidatorHelper: MockValidatorHelper!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()
        mockValidatorHelper = MockValidatorHelper(mockWalletKit: mockWalletKit)

        mockNetwork = BitcoinMainNet(validatorFactory: mockValidatorHelper.mockFactory)
    }

    override func tearDown() {
        mockNetwork = nil
        mockValidatorHelper = nil

        super.tearDown()
    }

    func testValidate() {
        let block = TestData.firstBlock
        do {
            try mockNetwork.validate(block: block, previousBlock: block.previousBlock!)
            verify(mockValidatorHelper.mockHeaderValidator, times(1)).validate(candidate: any(), block: any(), network: any())
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

}
