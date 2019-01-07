import XCTest
import Cuckoo
import RealmSwift
import RxSwift
@testable import HSBitcoinKit

class StateManagerTests: XCTestCase {

    private var mockRealmFactory: MockIRealmFactory!

    private var realm: Realm!
    private var stateManager: StateManager!

    override func setUp() {
        super.setUp()

        mockRealmFactory = MockIRealmFactory()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }
        stub(mockRealmFactory) {mock in
            when(mock.realm.get).thenReturn(realm)
        }

        stateManager = StateManager(realmFactory: mockRealmFactory, syncableFromApi: true, newWallet: false)
    }

    override func tearDown() {
        mockRealmFactory = nil
        realm = nil

        stateManager = nil

        super.tearDown()
    }

    func testConstructor() {
        XCTAssertFalse(stateManager.restored)

        stateManager = StateManager(realmFactory: mockRealmFactory, syncableFromApi: false, newWallet: false)
        XCTAssertTrue(stateManager.restored)

        stateManager = StateManager(realmFactory: mockRealmFactory, syncableFromApi: true, newWallet: true)
        XCTAssertTrue(stateManager.restored)

        stateManager = StateManager(realmFactory: mockRealmFactory, syncableFromApi: false, newWallet: true)
        XCTAssertTrue(stateManager.restored)
    }

    func testRestored_Set() {
        stateManager.restored = true
        XCTAssertTrue(realm.objects(RestoreState.self).first!.restored)

        stateManager.restored = false
        XCTAssertFalse(realm.objects(RestoreState.self).first!.restored)
    }
}
