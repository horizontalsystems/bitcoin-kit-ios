//import XCTest
//import Cuckoo
//import RealmSwift
//@testable import HSBitcoinKit
//
//class ProgressSyncerTests: XCTestCase {
//
//    private var mockRealmFactory: MockRealmFactory!
//    private var syncer: ProgressSyncer!
//
//    private var realm: Realm!
//
//    override func setUp() {
//        super.setUp()
//
//        let mockBitcoinKit = MockWalletKit()
//
//        realm = mockBitcoinKit.realm
//
//        syncer = ProgressSyncer(realmFactory: mockBitcoinKit.mockRealmFactory, queue: DispatchQueue.main)
//    }
//
//    override func tearDown() {
//        mockRealmFactory = nil
//        syncer = nil
//        realm = nil
//
//        super.tearDown()
//    }
//
//    func testInitialProgress() {
//        let disposable = syncer.subject.subscribe(onNext: { progress in
//            XCTAssertEqual(progress, 0)
//        })
//        disposable.dispose()
//    }
//
//    func testNoBlocks() {
//        syncer.enqueueRun()
//        waitForMainQueue()
//
//        let disposable = syncer.subject.subscribe(onNext: { progress in
//            XCTAssertEqual(progress, 0)
//        })
//        disposable.dispose()
//    }
//
//    func testPartialProgress() {
//        let block = TestData.thirdBlock
//
//        try! realm.write {
//            realm.add(block)
//        }
//
//        syncer.enqueueRun()
//        waitForMainQueue()
//
//        let disposable = syncer.subject.subscribe(onNext: { progress in
//            XCTAssertEqual(progress, 0.5)
//        })
//        disposable.dispose()
//    }
//
//    func testFullProgress() {
//        let block = TestData.secondBlock
//
//        try! realm.write {
//            realm.add(block)
//        }
//
//        syncer.enqueueRun()
//        waitForMainQueue()
//
//        let disposable = syncer.subject.subscribe(onNext: { progress in
//            XCTAssertEqual(progress, 1)
//        })
//        disposable.dispose()
//    }
//
//}
