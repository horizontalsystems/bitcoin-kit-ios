import XCTest
import Cuckoo
import HSHDWalletKit
@testable import HSBitcoinKit

class AddressManagerTests: XCTestCase {

    private var mockStorage: MockIStorage!
    private var mockHDWallet: MockIHDWallet!
    private var mockAddressConverter: MockIAddressConverter!

    private var hdWallet: IHDWallet!
    private var manager: AddressManager!

    override func setUp() {
        super.setUp()

        mockStorage = MockIStorage()
        mockHDWallet = MockIHDWallet()
        mockAddressConverter = MockIAddressConverter()

        stub(mockStorage) { mock in
            when(mock.add(publicKeys: any())).thenDoNothing()
        }

        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = AddressManager(storage: mockStorage, hdWallet: mockHDWallet, addressConverter: mockAddressConverter)
    }

    override func tearDown() {
        mockStorage = nil
        mockHDWallet = nil
        mockAddressConverter = nil

        hdWallet = nil
        manager = nil

        super.tearDown()
    }

    func testChangePublicKey() {
        let publicKeys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 3, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn(publicKeys)
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.keyHash, publicKeys[3].publicKey.keyHash)
    }

    func testChangePublicKey_NoUnusedPublicKey() {
        let publicKey = PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true)

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([publicKey])
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
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 3, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .external), used: false)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn(publicKeys)
        }

        let address = LegacyAddress(type: .pubKeyHash, keyHash: publicKeys[3].publicKey.keyHash, base58: "receiveAddress")
        stub(mockAddressConverter) { mock in
            when(mock.convert(keyHash: equal(to: publicKeys[3].publicKey.keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(address)
        }

        XCTAssertEqual(try? manager.receiveAddress(), address.stringValue)
        verify(mockAddressConverter).convert(keyHash: equal(to: publicKeys[3].publicKey.keyHash), type: equal(to: ScriptType.p2pkh))
    }

    func testReceiveAddress_NoUnusedPublicKey() {
        let publicKey = PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: true)

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([publicKey])
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
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0], keys[1]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[5].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[6].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[7].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[8].publicKey)
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 1), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 1), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[2].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[3].publicKey, keys[4].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[5].publicKey, keys[6].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[7].publicKey, keys[8].publicKey]))
    }

    func testFillGap_NoUsedKey() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[0].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[2].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[3].publicKey)
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))
        verify(mockHDWallet, never()).publicKey(account: equal(to: 1), index: any(), external: any())

        verify(mockStorage).add(publicKeys: equal(to: [keys[0].publicKey, keys[1].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[2].publicKey, keys[3].publicKey]))
    }

    func testFillGap_NoUnusedKeys() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[5].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[6].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[7].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[8].publicKey)
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[1].publicKey, keys[2].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[3].publicKey, keys[4].publicKey]))
    }

    func testFillGap_NonSequentiallyUsedKeys() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 3, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 1, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0], keys[1], keys[2], keys[3], keys[4]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(1)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 3), external: equal(to: false))).thenReturn(keys[5].publicKey)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: true))).thenReturn(keys[6].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[7].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[8].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[9].publicKey)
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[10].publicKey)
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[5].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[6].publicKey]))
    }

    func testAddKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
        ]

        try! manager.addKeys(keys: keys)
        verify(mockStorage).add(publicKeys: equal(to: keys))
    }

    func testGapShifts() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0], keys[1]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NoUnusedKeys() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NonSequentiallyUsedKeys() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .internal), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 3, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([keys[0], keys[1], keys[2], keys[3], keys[4]])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NoShift() {
        let keys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .external), used: false),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn(keys)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), false)
    }


    private func getPublicKey(withAccount account: Int, index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(account: account, index: index, external: chain == .external)
        return PublicKey(withAccount: account, index: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }
}
