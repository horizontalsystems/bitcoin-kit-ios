import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class AddressManagerTests: XCTestCase {

    private var mockWalletKit: MockWalletKit!
    private var mockHDWallet: MockHDWallet!
    private var mockPeerGroup: MockPeerGroup!
    private var hdWallet: HDWallet!
    private var manager: AddressManager!

    override func setUp() {
        super.setUp()

        mockWalletKit = MockWalletKit()
        mockHDWallet = mockWalletKit.mockHdWallet
        mockPeerGroup = mockWalletKit.mockPeerGroup
        hdWallet = HDWallet(seed: Data(), network: mockWalletKit.mockNetwork)

        stub(mockWalletKit.mockNetwork) { mock in
            when(mock.pubKeyHash.get).thenReturn(UInt8(0x6f))
        }
        stub(mockPeerGroup) { mock in
            when(mock.addPublicKeyFilter(pubKey: any())).thenDoNothing()
        }

        manager = AddressManager(realmFactory: mockWalletKit.mockRealmFactory, hdWallet: mockHDWallet, peerGroup: mockPeerGroup)
    }

    override func tearDown() {
        mockWalletKit = nil
        mockHDWallet = nil
        mockPeerGroup = nil
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

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add(publicKeys)
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = publicKeys[0]
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.address, publicKeys[3].address)
    }

    func testChangePublicKey_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withIndex: 0, chain: .internal)
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add(publicKey)
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = publicKey
        }

        let hdPrivKey = try! hdWallet.privateKey(index: 1, chain: .internal)
        let publicKey1 = PublicKey(withIndex: 1, external: false, hdPublicKey: hdPrivKey.publicKey())

        stub(mockHDWallet) { mock in
            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey1)
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.address, publicKey1.address)
        verify(mockHDWallet).publicKey(index: equal(to: 1), external: equal(to: false))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: publicKey1))
    }

    func testChangePublicKey_NoPublicKey() {
        let hdPrivKey = try! hdWallet.privateKey(index: 0, chain: .internal)
        let publicKey = PublicKey(withIndex: 0, external: false, hdPublicKey: hdPrivKey.publicKey())

        stub(mockHDWallet) { mock in
            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey)
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.address, publicKey.address)
        verify(mockHDWallet).publicKey(index: equal(to: 0), external: equal(to: false))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: publicKey))
    }

    func testChangePublicKey_ShouldSaveNewKey() {
        let hdPrivKey = try! hdWallet.privateKey(index: 0, chain: .internal)
        let publicKey = PublicKey(withIndex: 0, external: false, hdPublicKey: hdPrivKey.publicKey())

        stub(mockHDWallet) { mock in
            when(mock.publicKey(index: any(), external: equal(to: false))).thenReturn(publicKey)
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.address, publicKey.address)
        let saved = mockWalletKit.realm.objects(PublicKey.self).filter("address = %@", publicKey.address).last
        XCTAssertNotEqual(saved, nil)
    }

    func testReceivePublicKey() {
        let publicKeys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 3, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .external)
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add(publicKeys)
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = publicKeys[0]
        }

        XCTAssertEqual(try? manager.receiveAddress(), publicKeys[3].address)
    }

    func testReceivePublicKey_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withIndex: 0, chain: .external)
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add(publicKey)
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = publicKey
        }

        let hdPrivKey = try! hdWallet.privateKey(index: 1, chain: .external)
        let publicKey1 = PublicKey(withIndex: 1, external: false, hdPublicKey: hdPrivKey.publicKey())

        stub(mockHDWallet) { mock in
            when(mock.publicKey(index: any(), external: equal(to: true))).thenReturn(publicKey1)
        }

        XCTAssertEqual(try? manager.receiveAddress(), publicKey1.address)
        verify(mockHDWallet).publicKey(index: equal(to: 1), external: equal(to: true))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: publicKey1))
    }

    func testGenerateKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add([keys[0], keys[1]])
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
        }

        try! manager.generateKeys()
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[2]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[3]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[4]))

        let internalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 3)
        XCTAssertEqual(externalKeys.count, 2)
        XCTAssertEqual(internalKeys[2].address, keys[2].address)
        XCTAssertEqual(externalKeys[0].address, keys[3].address)
        XCTAssertEqual(externalKeys[1].address, keys[4].address)
    }

    func testGenerateKeys_NoUnusedKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .internal),
            getPublicKey(withIndex: 2, chain: .internal),
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 1, chain: .external),
        ]
        let txOutput = TestData.p2pkhTransaction.outputs[0]

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add([keys[0]])
            mockWalletKit.realm.add(txOutput)
            txOutput.publicKey = keys[0]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1])
            when(mock.publicKey(index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
        }

        try! manager.generateKeys()
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(index: any(), external: equal(to: true))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[1]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[2]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[3]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[4]))

        let internalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 3)
        XCTAssertEqual(externalKeys.count, 2)
        XCTAssertEqual(internalKeys[1].address, keys[1].address)
        XCTAssertEqual(internalKeys[2].address, keys[2].address)
        XCTAssertEqual(externalKeys[0].address, keys[3].address)
        XCTAssertEqual(externalKeys[1].address, keys[4].address)
    }

    func testGenerateKeys_NonSequentiallyUsedKeys() {
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

        try! mockWalletKit.realm.write {
            mockWalletKit.realm.add([keys[0], keys[1], keys[2], keys[3], keys[4]])
            mockWalletKit.realm.add([txOutput, txOutput2, txOutput3])
            txOutput.publicKey = keys[0]
            txOutput2.publicKey = keys[2]
            txOutput3.publicKey = keys[4]
        }

        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(1)
            when(mock.publicKey(index: equal(to: 3), external: equal(to: false))).thenReturn(keys[5])
            when(mock.publicKey(index: equal(to: 2), external: equal(to: true))).thenReturn(keys[6])
        }

        try! manager.generateKeys()
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: false))
        verify(mockHDWallet, times(1)).publicKey(index: any(), external: equal(to: true))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[5]))
        verify(mockPeerGroup).addPublicKeyFilter(pubKey: equal(to: keys[6]))

        let internalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = false").sorted(byKeyPath: "index")
        let externalKeys = mockWalletKit.realm.objects(PublicKey.self).filter("external = true").sorted(byKeyPath: "index")

        XCTAssertEqual(internalKeys.count, 4)
        XCTAssertEqual(externalKeys.count, 3)
        XCTAssertEqual(internalKeys[1].address, keys[1].address)
        XCTAssertEqual(internalKeys[2].address, keys[2].address)
        XCTAssertEqual(internalKeys[3].address, keys[5].address)
        XCTAssertEqual(externalKeys[0].address, keys[3].address)
        XCTAssertEqual(externalKeys[1].address, keys[4].address)
        XCTAssertEqual(externalKeys[2].address, keys[6].address)
    }

    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKey = try! hdWallet.privateKey(index: index, chain: chain)
        return PublicKey(withIndex: index, external: chain == .external, hdPublicKey: hdPrivKey.publicKey())
    }
}
