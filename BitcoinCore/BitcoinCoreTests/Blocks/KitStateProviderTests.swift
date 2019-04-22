//import XCTest
//import Cuckoo
//@testable import BitcoinCore
//
//class KitStateProviderTest: XCTestCase  {
//    private var mockDelegate: MockIKitStateProviderDelegate!
//    private var syncer: KitStateProvider!
//
//    override func setUp() {
//        super.setUp()
//
//        mockDelegate = MockIKitStateProviderDelegate()
//        stub(mockDelegate) { mock in
//            when(mock.handleKitStateUpdate(state: any())).thenDoNothing()
//        }
//
//        syncer = KitStateProvider()
//        syncer.delegate = mockDelegate
//    }
//
//    override func tearDown() {
//        super.tearDown()
//
//        mockDelegate = nil
//        syncer = nil
//    }
//
//    func testStartState() {
//        XCTAssertEqual(syncer.syncState, .notSynced)
//    }
//
//    func testSetState() {
//        syncer.syncStarted()
//
//        XCTAssertEqual(syncer.syncState, BitcoinKit.KitState.syncing(progress: 0))
//    }
//
//
//    func testIgnoreSameStateChange() {
//        syncer.syncStarted()
//        syncer.syncStarted()
//
//        verify(mockDelegate, times(1)).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0)))
//    }
//
//    func testSyncStarted() {
//        syncer.syncStarted()
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0)))
//    }
//
//    func testSyncStopped() {
//        syncer.syncStarted()
//        syncer.syncStopped()
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.notSynced))
//    }
//
//    func testSyncFinished() {
//        syncer.syncFinished()
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.synced))
//    }
//
//    func testInitialBestBlockHeightUpdated() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//
//        verify(mockDelegate, never()).handleKitStateUpdate(state: any())
//    }
//
//    func testCurrentBestBlockHeightUpdated() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//        syncer.currentBestBlockHeightUpdated(height: 101, maxBlockHeight: 200)
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0.01)))
//    }
//
//    func testCurrentBestBlockHeightUpdated_heightLessThanInitialHeight() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//        syncer.currentBestBlockHeightUpdated(height: 99, maxBlockHeight: 200)
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0)))
//    }
//
//    func testCurrentBestBlockHeightUpdated_heightMoreThanMaxHeight() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//        syncer.currentBestBlockHeightUpdated(height: 201, maxBlockHeight: 200)
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.synced))
//    }
//
//    func testCurrentBestBlockHeightUpdated_MaxHeightLessThanInitialHeight() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//        syncer.currentBestBlockHeightUpdated(height: 99, maxBlockHeight: 99)
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.synced))
//    }
//
//    func testCurrentBestBlockHeightUpdated_heightMustNotDecrease() {
//        syncer.initialBestBlockHeightUpdated(height: 100)
//        syncer.currentBestBlockHeightUpdated(height: 102, maxBlockHeight: 200)
//        syncer.currentBestBlockHeightUpdated(height: 101, maxBlockHeight: 200)
//
//        verify(mockDelegate).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0.02)))
//        verify(mockDelegate, never()).handleKitStateUpdate(state: equal(to: BitcoinKit.KitState.syncing(progress: 0.01)))
//    }
//
//}
