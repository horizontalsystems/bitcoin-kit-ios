import XCTest
import Cuckoo
import HSHDWalletKit
import RealmSwift
@testable import HSBitcoinKit

class AddressManagerTests: XCTestCase {

    private var realm: Realm!
    private var mockRealmFactory: MockIRealmFactory!
    private var mockHDWallet: MockIHDWallet!
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
        mockAddressConverter = MockIAddressConverter()

        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = AddressManager(realmFactory: mockRealmFactory, hdWallet: mockHDWallet, addressConverter: mockAddressConverter)
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockHDWallet = nil
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

    func testChangePublicKey_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withIndex: 0, chain: .internal)
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add(publicKey)
            realm.add(txOutput)
            txOutput.publicKey = publicKey
        }

        do {
            let _ = try manager.changePublicKey()
            XCTFail("Should throw exception")
        } catch let error as AddressManager.AddressManagerError {
            XCTAssertEqual(error, AddressManager.AddressManagerError.noUnusedPublicKey)
        } catch {
            XCTFail("Unexpected exception thrown")
        }
    }

    func testReceiveAddress() {
        let publicKeys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 3, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .external)
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add(publicKeys)
            realm.add(txOutput)
            txOutput.publicKey = publicKeys[0]
        }

        let address = LegacyAddress(type: .pubKeyHash, keyHash: publicKeys[3].keyHash, base58: "receiveAddress")
        stub(mockAddressConverter) { mock in
            when(mock.convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(address)
        }

        XCTAssertEqual(try? manager.receiveAddress(), address.stringValue)
        verify(mockAddressConverter).convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))
    }

    func testReceiveAddress_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withIndex: 0, chain: .external)
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add(publicKey)
            realm.add(txOutput)
            txOutput.publicKey = publicKey
        }

        do {
            let _ = try manager.receiveAddress()
            XCTFail("Should throw exception")
        } catch let error as AddressManager.AddressManagerError {
            XCTAssertEqual(error, AddressManager.AddressManagerError.noUnusedPublicKey)
        } catch {
            XCTFail("Unexpected exception thrown")
        }
    }

    func testFillGap() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0], keys[1]])
            realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))

        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 3)
        XCTAssertEqual(externalKeys.count, 2)
        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
    }

    func testFillGap_NoUnusedKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0]])
            realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1])
            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))

        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 3)
        XCTAssertEqual(externalKeys.count, 2)
        XCTAssertEqual(internalKeys[1].keyHash, keys[1].keyHash)
        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
    }

    func testFillGap_NonSequentiallyUsedKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
            getPublicKey(withIndex: 3, chain: .internal),
            getPublicKey(withIndex: 2, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]
        let txOutput2 = TestData.p2pkTransaction.outputs[0]
        let txOutput3 = TestData.p2shTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0], keys[1], keys[2], keys[3], keys[4]])
            realm.add([txOutput, txOutput2, txOutput3])
            txOutput.publicKey = keys[0]
            txOutput2.publicKey = keys[2]
            txOutput3.publicKey = keys[4]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(1)
            when(mock.publicKey(index: equal(to: 3), external: equal(to: false))).thenReturn(keys[5])
            when(mock.publicKey(index: equal(to: 2), external: equal(to: true))).thenReturn(keys[6])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: true))

        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 4)
        XCTAssertEqual(externalKeys.count, 3)
        XCTAssertEqual(internalKeys[0].keyHash, keys[0].keyHash)
        XCTAssertEqual(internalKeys[1].keyHash, keys[1].keyHash)
        XCTAssertEqual(internalKeys[2].keyHash, keys[2].keyHash)
        XCTAssertEqual(internalKeys[3].keyHash, keys[5].keyHash)
        XCTAssertEqual(externalKeys[0].keyHash, keys[3].keyHash)
        XCTAssertEqual(externalKeys[1].keyHash, keys[4].keyHash)
        XCTAssertEqual(externalKeys[2].keyHash, keys[6].keyHash)
    }

    func testAddKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
        ]

        try! manager.addKeys(keys: keys)

        let internalKeys = realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 2)
        XCTAssertEqual(externalKeys.count, 1)
        XCTAssertEqual(internalKeys[0].keyHash, keys[0].keyHash)
        XCTAssertEqual(internalKeys[1].keyHash, keys[1].keyHash)
        XCTAssertEqual(externalKeys[0].keyHash, keys[2].keyHash)
    }

    func testGapShifts() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0], keys[1]])
            realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(index: any(), external: any())
    }

    func testGapShifts_NoUnusedKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0]])
            realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(index: any(), external: any())
    }

    func testGapShifts_NonSequentiallyUsedKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
            getPublicKey(withIndex: 3, chain: .internal),
            getPublicKey(withIndex: 2, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]
        let txOutput2 = TestData.p2pkTransaction.outputs[0]
        let txOutput3 = TestData.p2shTransaction.outputs[0]

        try! realm.write {
            realm.add([keys[0], keys[1], keys[2], keys[3], keys[4]])
            realm.add([txOutput, txOutput2, txOutput3])
            txOutput.publicKey = keys[0]
            txOutput2.publicKey = keys[2]
            txOutput3.publicKey = keys[4]
        }


        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(index: any(), external: any())
    }

    func testGapShifts_NoShift() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
            getPublicKey(withIndex: 2, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! realm.write {
            realm.add(keys)
            realm.add(txOutput)
            txOutput.publicKey = keys[2]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), false)
    }


    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(index: index, external: chain == .external)
        return PublicKey(withIndex: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }
}
