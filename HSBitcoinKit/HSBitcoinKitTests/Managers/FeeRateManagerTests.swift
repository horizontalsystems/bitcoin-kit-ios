import XCTest
import RxSwift
import Cuckoo
@testable import HSBitcoinKit

class FeeRateManagerTests: XCTestCase {
    enum AnyError: Error { case any }

    private var mockStorage: MockIFeeRateStorage!
    private var mockSyncer: MockIFeeRateSyncer!
    private var mockReachabilityManager: MockIReachabilityManager!

    private var manager: FeeRateManager!

    private let feeRate = FeeRate()
    private let reachabilitySubject = PublishSubject<()>()

    override func setUp() {
        super.setUp()

        feeRate.lowPriority = 0
        feeRate.mediumPriority = 0
        feeRate.highPriority = 0
        feeRate.date = Date()

        mockStorage = MockIFeeRateStorage()
        mockSyncer = MockIFeeRateSyncer()
        mockReachabilityManager = MockIReachabilityManager()

        stub(mockStorage) { mock in
            when(mock.feeRate.get).thenReturn(feeRate)
            when(mock.save(feeRate: any())).thenDoNothing()
        }
        stub(mockSyncer) { mock in
            when(mock.sync()).then {
                print("sdfsdfdssdf")
            }
            when(mock.delegate.set(any())).thenDoNothing()
        }
        stub(mockReachabilityManager) { mock in
            when(mock.reachabilitySignal.get).thenReturn(reachabilitySubject)
            when(mock.isReachable.get).thenReturn(false)
        }

        manager = FeeRateManager(storage: mockStorage, syncer: mockSyncer, reachabilityManager: mockReachabilityManager, async: false)
    }

    override func tearDown() {
        mockStorage = nil
        mockSyncer = nil
        mockReachabilityManager = nil

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
        stub(mockReachabilityManager) { mock in
            when(mock.isReachable.get).thenReturn(true)
        }
        reachabilitySubject.onNext(())

        waitForMainQueue()

        verify(mockSyncer, atLeastOnce()).sync()
    }

    func testSyncFeeRate_OnReachabilityChanged_Disconnected() {
        stub(mockReachabilityManager) { mock in
            when(mock.isReachable.get).thenReturn(false)
        }
        reachabilitySubject.onNext(())
        verify(mockSyncer, never()).sync()
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
