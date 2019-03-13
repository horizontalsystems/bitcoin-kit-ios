import XCTest
import RxSwift
import Cuckoo
@testable import HSBitcoinKit

class FeeRateSyncerTests: XCTestCase {
    private var mockApi: MockIFeeRateApi!
    private var mockStorage: MockIStorage!

    private var syncer: FeeRateSyncer!

    override func setUp() {
        super.setUp()

        mockApi = MockIFeeRateApi()
        mockStorage = MockIStorage()

        syncer = FeeRateSyncer(api: mockApi, storage: mockStorage)
    }

    override func tearDown() {
        mockApi = nil
        mockStorage = nil

        syncer = nil

        super.tearDown()
    }

    func testSync() {
        let feeRate = FeeRate.defaultFeeRate

        stub(mockApi) { mock in
            when(mock.getFeeRate()).thenReturn(Observable.just(feeRate))
        }
        stub(mockStorage) { mock in
            when(mock.set(feeRate: any())).thenDoNothing()
        }

        syncer.sync()

        verify(mockStorage).set(feeRate: equal(to: feeRate))
    }

}
