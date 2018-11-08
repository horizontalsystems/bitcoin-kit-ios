import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class ProgressSyncerTest: XCTestCase  {
    private var mockDelegate: MockProgressSyncerDelegate!
    private var syncer: ProgressSyncer!

    override func setUp() {
        super.setUp()

        mockDelegate = MockProgressSyncerDelegate()
        stub(mockDelegate) { mock in
            when(mock.handleProgressUpdate(progress: any())).thenDoNothing()
        }

        syncer = ProgressSyncer()
        syncer.delegate = mockDelegate
    }

    override func tearDown() {
        super.tearDown()

        mockDelegate = nil
        syncer = nil
    }

    func testProgress_initialBestBlockHeightUpdated() {
        syncer.initialBestBlockHeightUpdated(height: 100)

        verify(mockDelegate, never()).handleProgressUpdate(progress: any())
    }

    func testProgress_onReceiveMaxBlockHeight_remoteLonger() {
        syncer.initialBestBlockHeightUpdated(height: 100)
        syncer.bestBlockHeightReceived(height: 123)

        verify(mockDelegate).handleProgressUpdate(progress: equal(to: 0.0))
    }

    func testProgress_onReceiveMaxBlockHeight_localLonger() {
        syncer.initialBestBlockHeightUpdated(height: 100)
        syncer.bestBlockHeightReceived(height: 90)

        verify(mockDelegate).handleProgressUpdate(progress: equal(to: 1.0))
    }

    func testProgress_onReceiveMaxBlockHeight_alreadySynced() {
        syncer.initialBestBlockHeightUpdated(height: 100)
        syncer.bestBlockHeightReceived(height: 100)

        verify(mockDelegate).handleProgressUpdate(progress: equal(to: 1.0))
    }

    func testProgress_simple() {
        syncer.initialBestBlockHeightUpdated(height: 0)
        syncer.bestBlockHeightReceived(height: 100)
        syncer.currentBestBlockHeightUpdated(height: 23)

        verify(mockDelegate).handleProgressUpdate(progress: equal(to: 0.23))
    }

    func testProgress_remoteLongerThanAnnounced() {
        syncer.initialBestBlockHeightUpdated(height: 0)
        syncer.bestBlockHeightReceived(height: 100)
        syncer.currentBestBlockHeightUpdated(height: 200)

        verify(mockDelegate).handleProgressUpdate(progress: equal(to: 1.0))
    }

}