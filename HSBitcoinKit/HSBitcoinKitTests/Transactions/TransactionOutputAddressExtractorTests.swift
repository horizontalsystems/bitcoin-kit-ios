import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionOutputAddressExtractorTests: XCTestCase {
    private var extractor: TransactionOutputAddressExtractor!
    private var mockAddressConverter: MockIAddressConverter!

    private var transaction: Transaction!

    override func setUp() {
        super.setUp()

        mockAddressConverter = MockIAddressConverter()
        extractor = TransactionOutputAddressExtractor(addressConverter: mockAddressConverter)
        transaction = TestData.p2pkhTransaction
    }

    override func tearDown() {
        extractor = nil
        transaction = nil

        super.tearDown()
    }

    func testExtractor() {

    }

}
