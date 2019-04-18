import XCTest
import Cuckoo
@testable import BitcoinCore

class TransactionOutputAddressExtractorTests: XCTestCase {
    private var extractor: TransactionOutputAddressExtractor!
    private var mockAddressConverter: MockIAddressConverter!
    private var mockStorage: MockIStorage!

    private var transaction: FullTransaction!

    override func setUp() {
        super.setUp()

        mockAddressConverter = MockIAddressConverter()
        mockStorage = MockIStorage()
        extractor = TransactionOutputAddressExtractor(storage: mockStorage, addressConverter: mockAddressConverter)
        transaction = TestData.p2pkhTransaction
    }

    override func tearDown() {
        extractor = nil
        transaction = nil
        mockStorage = nil
        mockAddressConverter = nil

        super.tearDown()
    }

    func testExtractor() {

    }

}
