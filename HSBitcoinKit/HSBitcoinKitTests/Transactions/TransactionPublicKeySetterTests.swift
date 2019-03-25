//import XCTest
//import Cuckoo
//@testable import HSBitcoinKit
//
//class TransactionPublicKeySetterTests: XCTestCase {
//    private var realm: Realm!
//
//    private var publicKey: PublicKey!
//    private var transactionKeySetter: TransactionPublicKeySetter!
//
//    override func setUp() {
//        super.setUp()
//
//        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
//
//        let mockRealmFactory = MockIRealmFactory()
//        stub(mockRealmFactory) { mock in
//            when(mock.realm.get).thenReturn(realm)
//        }
//
//        publicKey = PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data(hex: "0011223344")!)
//        try! realm.write {
//            realm.deleteAll()
//            realm.add(publicKey)
//        }
//
//        transactionKeySetter = TransactionPublicKeySetter(realmFactory: mockRealmFactory)
//    }
//
//    override func tearDown() {
//        realm = nil
//
//        super.tearDown()
//    }
//
//    func testSetP2PKHKeys() {
//        let tx = TestData.p2pkhTransaction
//        tx.outputs[0].keyHash = publicKey.keyHash
//        let mine = transactionKeySetter.set(output: tx.outputs[0])
//
//        XCTAssertEqual(mine, true)
//        XCTAssertEqual(tx.outputs[0].publicKey, publicKey)
//
//        let notMine = transactionKeySetter.set(output: tx.outputs[1])
//        XCTAssertEqual(notMine, false)
//    }
//
//    func testSetP2PKKeys() {
//        let tx = TestData.p2pkhTransaction
//        tx.outputs[0].keyHash = publicKey.raw
//        let mine = transactionKeySetter.set(output: tx.outputs[0])
//
//        XCTAssertEqual(mine, true)
//        XCTAssertEqual(tx.outputs[0].publicKey, publicKey)
//    }
//
//    func testSetP2WPKHSHKeys() {
//        let tx = TestData.p2pkhTransaction
//        tx.outputs[0].scriptType = .p2wpkh
//        tx.outputs[0].keyHash = Data(hex: "0014")! + publicKey.scriptHashForP2WPKH
//        let mine = transactionKeySetter.set(output: tx.outputs[0])
//
//        XCTAssertEqual(mine, true)
//        XCTAssertEqual(tx.outputs[0].publicKey, publicKey)
//        XCTAssertEqual(tx.outputs[0].scriptType, .p2wpkhSh)
//    }
//
//}
