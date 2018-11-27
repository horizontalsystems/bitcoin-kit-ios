import XCTest
import RxSwift
import Cuckoo
@testable import HSBitcoinKit

class FeeRateManagerTests: XCTestCase {
    enum AnyError: Error { case any }

    private var mockStorage: MockIFeeRateStorage!
    private var mockSyncer: MockIFeeRateSyncer!
    private var mockReachabilityManager: MockIReachabilityManager!
    private var mockTimer: MockIPeriodicTimer!

    private var manager: FeeRateManager!

    private let feeRate = FeeRate(dateInterval: 0, date: "", low: 0, medium: 0, high: 0)
    private let reachabilitySubject = PublishSubject<Bool>()

    override func setUp() {
        super.setUp()

        mockStorage = MockIFeeRateStorage()
        mockSyncer = MockIFeeRateSyncer()
        mockReachabilityManager = MockIReachabilityManager()
        mockTimer = MockIPeriodicTimer()

        stub(mockStorage) { mock in
            when(mock.feeRate.get).thenReturn(feeRate)
            when(mock.save(feeRate: any())).thenDoNothing()
        }
        stub(mockSyncer) { mock in
            when(mock.sync()).thenDoNothing()
        }
        stub(mockReachabilityManager) { mock in
            when(mock.subject.get).thenReturn(reachabilitySubject)
        }
        stub(mockTimer) { mock in
            when(mock.delegate.set(any())).thenDoNothing()
            when(mock.schedule()).thenDoNothing()
        }


        manager = FeeRateManager(storage: mockStorage, syncer: mockSyncer, reachabilityManager: mockReachabilityManager, timer: mockTimer)
    }

    override func tearDown() {
        mockStorage = nil
        mockSyncer = nil
        mockReachabilityManager = nil
        mockTimer = nil

        manager = nil

        super.tearDown()
    }

    func testFeeRate() {
        XCTAssertEqual(manager.feeRate, feeRate)
    }

    func testDefaultFeeRate() {
        stub(mockStorage) { mock in
            when(mock.feeRate.get).thenReturn(nil)
        }

        XCTAssertEqual(manager.feeRate, FeeRate.defaultFeeRate)
    }

    func testSyncFeeRate_OnReachabilityChanged_Connected() {
        reachabilitySubject.onNext(true)
        verify(mockSyncer).sync()
    }

    func testSyncFeeRate_OnReachabilityChanged_Disconnected() {
        reachabilitySubject.onNext(false)
        verify(mockSyncer, never()).sync()
    }

    func testSyncFeeRate_OnTimerTick() {
        manager.onFire()
        verify(mockSyncer).sync()
    }

    func testDidSyncRate() {
        let subjectExpectation = expectation(description: "Subject")
        _ = manager.subject.subscribe(onNext: {
            subjectExpectation.fulfill()
        })

        let currentFeeRate = FeeRate.defaultFeeRate
        manager.didSync(feeRate: currentFeeRate)

        verify(mockStorage).save(feeRate: equal(to: currentFeeRate))
        waitForExpectations(timeout: 2)
    }

}
