import XCTest
import Cuckoo
import RxSwift
@testable import BitcoinCore

class StateManagerTests: XCTestCase {
    private var mockStorage: MockIStorage!

    private var manager: ApiSyncStateManager!

    override func setUp() {
        super.setUp()

        mockStorage = MockIStorage()

        stub(mockStorage) { mock in
            when(mock.set(initialRestored: any())).thenDoNothing()
        }

        manager = ApiSyncStateManager(storage: mockStorage, restoreFromApi: true)
    }

    override func tearDown() {
        mockStorage = nil
        manager = nil

        super.tearDown()
    }

    func testRestored_get_newWallet() {
        let manager = ApiSyncStateManager(storage: mockStorage, restoreFromApi: false)

        XCTAssertTrue(manager.restored)
    }

    func testRestored_get_true() {
        stub(mockStorage) { mock in
            when(mock.initialRestored.get).thenReturn(true)
        }

        XCTAssertTrue(manager.restored)
    }

    func testRestored_get_nilFromStorage() {
        stub(mockStorage) { mock in
            when(mock.initialRestored.get).thenReturn(nil)
        }

        XCTAssertFalse(manager.restored)
    }

    func testRestored_set_true() {
        manager.restored = true

        verify(mockStorage).set(initialRestored: true)
    }

    func testRestored_set_false() {
        manager.restored = false

        verify(mockStorage).set(initialRestored: false)
    }

}
