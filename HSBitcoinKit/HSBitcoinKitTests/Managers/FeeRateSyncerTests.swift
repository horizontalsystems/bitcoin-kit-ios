import XCTest
import RxSwift
import Cuckoo
@testable import HSBitcoinKit

class FeeRateSyncerTests: XCTestCase {
    enum AnyError: Error { case any }

    private var mockDelegate: MockIFeeRateSyncerDelegate!
    private var mockNetworkManager: MockIFeeRateApi!
    private var mockTimer: MockIPeriodicTimer!


    private var syncer: FeeRateSyncer!

    private let feeRate = FeeRate.defaultFeeRate

    override func setUp() {
        super.setUp()

        mockDelegate = MockIFeeRateSyncerDelegate()
        mockNetworkManager = MockIFeeRateApi()
        mockTimer = MockIPeriodicTimer()

        stub(mockNetworkManager) { mock in
            when(mock.getFeeRate()).thenReturn(Observable.just(feeRate))
        }
        stub(mockDelegate) { mock in
            when(mock.didSync(feeRate: any())).thenDoNothing()
        }
        stub(mockTimer) { mock in
            when(mock.schedule()).thenDoNothing()
        }

        syncer = FeeRateSyncer(networkManager: mockNetworkManager, timer: mockTimer, async: false)
        syncer.delegate = mockDelegate
    }

    override func tearDown() {
        mockDelegate = nil
        mockNetworkManager = nil
        mockTimer = nil

        syncer = nil

        super.tearDown()
    }

    func testSync() {
        syncer.sync()

        verify(mockDelegate).didSync(feeRate: equal(to: feeRate))
    }

    func testInvalidateTimerOnSync() {
        syncer.sync()

        verify(mockTimer).schedule()
    }

    func testNonInvalidateTimerOnError() {
        stub(mockNetworkManager) { mock in
            when(mock.getFeeRate()).thenReturn(Observable.error(AnyError.any))
        }
        syncer.sync()

        verifyNoMoreInteractions(mockTimer)
    }

}
