import XCTest
import Cuckoo
import HSHDWalletKit
import RealmSwift
import HSHDWalletKit
@testable import HSBitcoinKit

class AddressManagerTests: XCTestCase {

    private var realm: Realm!
    private var mockRealmFactory: MockIRealmFactory!
    private var mockHDWallet: MockIHDWallet!
    private var mockBloomFilterManager: MockIBloomFilterManager!
    private var mockAddressConverter: MockIAddressConverter!

    private var hdWallet: IHDWallet!
    private var manager: AddressManager!

    override func setUp() {
        super.setUp()

        mockRealmFactory = MockIRealmFactory()
        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }
        stub(mockRealmFactory) {mock in
            when(mock.realm.get).thenReturn(realm)
        }

        mockHDWallet = MockIHDWallet()
        mockBloomFilterManager = MockIBloomFilterManager()
        mockAddressConverter = MockIAddressConverter()

        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = AddressManager(realmFactory: mockRealmFactory, hdWallet: mockHDWallet, bloomFilterManager: mockBloomFilterManager, addressConverter: mockAddressConverter)
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockHDWallet = nil
        mockBloomFilterManager = nil
        mockAddressConverter = nil

        hdWallet = nil
        manager = nil

        super.tearDown()
    }

    func testChangePublicKey() {
        let publicKeys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 3, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 1, chain: .external)
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add(publicKeys)
            realm.add(txOutput)
            txOutput.publicKey = publicKeys[0]
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.keyHash, publicKeys[3].keyHash)
    }
//
//    func testChangePublicKey_NoUnusedPublicKey() {
//        let publicKey =  getPublicKey(withIndex: 0, chain: .internal)
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add(publicKey)
//            realm.add(txOutput)
//            txOutput.publicKey = publicKey
//        }
//
//        let hdPrivKey = try! hdWallet.privateKey(index: 1, chain: .internal)
//        let publicKey1 = PublicKey(withIndex: 1, external: false, hdPublicKey: hdPrivKey.publicKey())
//
//        stub(mockHDWallet) { mock in
//            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey1)
//        }
//
//        let changePublicKey = try! manager.changePublicKey()
//        XCTAssertEqual(changePublicKey.keyHash, publicKey1.keyHash)
//        verify(mockHDWallet).publicKey(index: equal(to: 1), external: equal(to: false))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//    }
//
//    func testChangePublicKey_NoPublicKey() {
//        let hdPrivKey = try! hdWallet.privateKey(index: 0, chain: .internal)
//        let publicKey = PublicKey(withIndex: 0, external: false, hdPublicKey: hdPrivKey.publicKey())
//
//        stub(mockHDWallet) { mock in
//            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey)
//        }
//
//        let changePublicKey = try! manager.changePublicKey()
//        XCTAssertEqual(changePublicKey.keyHash, publicKey.keyHash)
//        verify(mockHDWallet).publicKey(index: equal(to: 0), external: equal(to: false))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//    }
//
//    func testChangePublicKey_ShouldSaveNewKey() {
//        let hdPrivKey = try! hdWallet.privateKey(index: 0, chain: .internal)
//        let publicKey = PublicKey(withIndex: 0, external: false, hdPublicKey: hdPrivKey.publicKey())
//
//        stub(mockHDWallet) { mock in
//            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey)
//        }
//
//        let changePublicKey = try! manager.changePublicKey()
//        XCTAssertEqual(changePublicKey.keyHash, publicKey.keyHash)
//        let saved = realm.objects(PublicKey.self).filter("keyHash = %@", publicKey.keyHash).last
//        XCTAssertNotEqual(saved, nil)
//    }
//
//    func testReceiveAddress() {
//        let publicKeys = [
//            getPublicKey(withIndex: 0, chain: .external),
//            getPublicKey(withIndex: 0, chain: .internal),
//            getPublicKey(withIndex: 3, chain: .external),
//            getPublicKey(withIndex: 1, chain: .external),
//            getPublicKey(withIndex: 1, chain: .internal),
//            getPublicKey(withIndex: 2, chain: .external)
//        ]
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add(publicKeys)
//            realm.add(txOutput)
//            txOutput.publicKey = publicKeys[0]
//        }
//
//        let address = LegacyAddress(type: .pubKeyHash, keyHash: publicKeys[3].keyHash, base58: "receiveAddress")
//        stub(mockAddressConverter) { mock in
//            when(mock.convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(address)
//        }
//
//        XCTAssertEqual(try? manager.receiveAddress(), address.stringValue)
//        verify(mockAddressConverter).convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))
//    }
//
//    func testReceiveAddress_NoUnusedPublicKey() {
//        let publicKey =  getPublicKey(withIndex: 0, chain: .external)
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add(publicKey)
//            realm.add(txOutput)
//            txOutput.publicKey = publicKey
//        }
//
//        let hdPrivKey = try! hdWallet.privateKey(index: 1, chain: .external)
//        let publicKey1 = PublicKey(withIndex: 1, external: false, hdPublicKey: hdPrivKey.publicKey())
//        let address = LegacyAddress(type: .pubKeyHash, keyHash: publicKey1.keyHash, base58: "receiveAddress")
//
//        stub(mockHDWallet) { mock in
//            when(mock.publicKey(index: any(), external: equal(to: true))).thenReturn(publicKey1)
//        }
//        stub(mockAddressConverter) { mock in
//            when(mock.convert(keyHash: equal(to: publicKey1.keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(address)
//        }
//
//        XCTAssertEqual(try? manager.receiveAddress(), address.stringValue)
//        verify(mockAddressConverter).convert(keyHash: equal(to: publicKey1.keyHash), type: equal(to: ScriptType.p2pkh))
//        verify(mockHDWallet).publicKey(index: equal(to: 1), external: equal(to: true))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//    }
//
//    func testFillGap() {
//        let keys = [
//            getPublicKey(withIndex: 0, chain: .internal),
//            getPublicKey(withIndex: 1, chain: .internal),
//            getPublicKey(withIndex: 2, chain: .internal),
//            getPublicKey(withIndex: 0, chain: .external),
//            getPublicKey(withIndex: 1, chain: .external),
//        ]
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add([keys[0], keys[1]])
//            realm.add(txOutput)
//            txOutput.publicKey = keys[0]
//        }
//
//        stub(mockHDWallet) { mock in
//            when(mock.gapLimit.get).thenReturn(2)
//            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
//            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
//            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
//        }
//
//        try! manager.fillGap()
//        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
//        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//
//        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
//        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")
//
//        XCTAssertEqual(internalKeys.count, 3)
//        XCTAssertEqual(externalKeys.count, 2)
//        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
//        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
//        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
//    }
//
//    func testFillGap_NoUnusedKeys() {
//        let keys = [
//            getPublicKey(withIndex: 0, chain: .internal),
//            getPublicKey(withIndex: 1, chain: .internal),
//            getPublicKey(withIndex: 2, chain: .internal),
//            getPublicKey(withIndex: 0, chain: .external),
//            getPublicKey(withIndex: 1, chain: .external),
//        ]
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add([keys[0]])
//            realm.add(txOutput)
//            txOutput.publicKey = keys[0]
//        }
//
//        stub(mockHDWallet) { mock in
//            when(mock.gapLimit.get).thenReturn(2)
//            when(mock.publicKey(index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1])
//            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
//            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
//            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
//        }
//
//        try! manager.fillGap()
//        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: false))
//        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//
//        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
//        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")
//
//        XCTAssertEqual(internalKeys.count, 3)
//        XCTAssertEqual(externalKeys.count, 2)
//        XCTAssertEqual(internalKeys[1].keyHash, keys[1].keyHash)
//        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
//        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
//        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
//    }
//
//    func testFillGap_NonSequentiallyUsedKeys() {
//        let keys = [
//            getPublicKey(withIndex: 0, chain: .internal),
//            getPublicKey(withIndex: 1, chain: .internal),
//            getPublicKey(withIndex: 2, chain: .internal),
//            getPublicKey(withIndex: 0, chain: .external),
//            getPublicKey(withIndex: 1, chain: .external),
//            getPublicKey(withIndex: 3, chain: .internal),
//            getPublicKey(withIndex: 2, chain: .external),
//        ]
//        let txOutput = TestData.p2pkhTransaction.outputs[0]
//        let txOutput2 = TestData.p2pkTransaction.outputs[0]
//        let txOutput3 = TestData.p2shTransaction.outputs[0]
//
//        try! realm.write {
//            realm.add([keys[0], keys[1], keys[2], keys[3], keys[4]])
//            realm.add([txOutput, txOutput2, txOutput3])
//            txOutput.publicKey = keys[0]
//            txOutput2.publicKey = keys[2]
//            txOutput3.publicKey = keys[4]
//        }
//
//        stub(mockHDWallet) { mock in
//            when(mock.gapLimit.get).thenReturn(1)
//            when(mock.publicKey(index: equal(to: 3), external: equal(to: false))).thenReturn(keys[5])
//            when(mock.publicKey(index: equal(to: 2), external: equal(to: true))).thenReturn(keys[6])
//        }
//
//        try! manager.fillGap()
//        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
//        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: true))
//        verify(mockBloomFilterManager).regenerateBloomFilter()
//
//        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
//        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")
//
//        XCTAssertEqual(internalKeys.count, 4)
//        XCTAssertEqual(externalKeys.count, 3)
//        XCTAssertEqual(internalKeys[1].keyHash, keys[1].keyHash)
//        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
//        XCTAssertEqual(internalKeys[3].keyHash, keys[5].keyHash)
//        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
//        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
//        XCTAssertEqual(externalKeys[2].keyHash, keys[6].keyHash)
//    }
//
//    func testAddKeys() {
//
//    }
//
//    func testGapShifts() {
//
//    }


    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(index: index, external: chain == .external)
        return PublicKey(withIndex: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }
}
