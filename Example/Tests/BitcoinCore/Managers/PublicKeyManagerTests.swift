import XCTest
import Cuckoo
import HdWalletKit
@testable import BitcoinCore

class PublicKeyManagerTests: XCTestCase {

    private var mockStorage: MockIStorage!
    private var mockHDWallet: MockIHDWallet!
    private var mockAddressConverter: MockIAddressConverter!
    private var mockRestoreKeyConverter: MockIRestoreKeyConverter!
    private var mockBloomFilterManager: MockIBloomFilterManager!

    private var hdWallet: IHDWallet!
    private var manager: PublicKeyManager!

    override func setUp() {
        super.setUp()

        mockStorage = MockIStorage()
        mockHDWallet = MockIHDWallet()
        mockAddressConverter = MockIAddressConverter()
        mockRestoreKeyConverter = MockIRestoreKeyConverter()
        mockBloomFilterManager = MockIBloomFilterManager()

        stub(mockStorage) { mock in
            when(mock.add(publicKeys: any())).thenDoNothing()
        }
        stub(mockBloomFilterManager) { mock in
            when(mock.regenerateBloomFilter()).thenDoNothing()
        }

        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = PublicKeyManager(storage: mockStorage, hdWallet: mockHDWallet, restoreKeyConverter: mockRestoreKeyConverter)
        manager.bloomFilterManager = mockBloomFilterManager
    }

    override func tearDown() {
        mockStorage = nil
        mockHDWallet = nil
        mockAddressConverter = nil
        mockRestoreKeyConverter = nil
        mockBloomFilterManager = nil

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
        } catch let error as PublicKeyManager.PublicKeyManagerError {
            XCTAssertEqual(error, PublicKeyManager.PublicKeyManagerError.noUnusedPublicKey)
        } catch {
            XCTFail("Unexpected exception thrown")
        }
    }

    func testReceivePublicKey() {
        let publicKeys = [
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: true),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .internal), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 3, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 2, chain: .external), used: false),
            PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 1, chain: .internal), used: false)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn(publicKeys)
        }

        let changePublicKey = try! manager.receivePublicKey()
        XCTAssertEqual(changePublicKey.keyHash, publicKeys[3].publicKey.keyHash)
    }

    func testReceivePublicKey_NoUnusedPublicKey() {
        let publicKey = PublicKeyWithUsedState(publicKey: getPublicKey(withAccount: 0, index: 0, chain: .external), used: true)

        stub(mockStorage) { mock in
            when(mock.publicKeysWithUsedState()).thenReturn([publicKey])
        }

        do {
            let _ = try manager.receivePublicKey()
            XCTFail("Should throw exception")
        } catch let error as PublicKeyManager.PublicKeyManagerError {
            XCTAssertEqual(error, PublicKeyManager.PublicKeyManagerError.noUnusedPublicKey)
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
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(2)..<UInt32(3)), external: false)).thenReturn([keys[2].publicKey])
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(2)), external: true)).thenReturn([keys[3].publicKey, keys[4].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(2)), external: false)).thenReturn([keys[5].publicKey, keys[6].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(2)), external: true)).thenReturn([keys[7].publicKey, keys[8].publicKey])
        }

        try! manager.fillGap()

        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(2)..<UInt32(3)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: true))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[2].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[3].publicKey, keys[4].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[5].publicKey, keys[6].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[7].publicKey, keys[8].publicKey]))

        verify(mockBloomFilterManager).regenerateBloomFilter()

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
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(2)), external: false)).thenReturn([keys[0].publicKey, keys[1].publicKey])
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(2)), external: true)).thenReturn([keys[2].publicKey, keys[3].publicKey])
        }

        try! manager.fillGap()
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: true))
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
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(1)..<UInt32(3)), external: false)).thenReturn([keys[1].publicKey, keys[2].publicKey])
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(2)), external: true)).thenReturn([keys[3].publicKey, keys[4].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(2)), external: false)).thenReturn([keys[5].publicKey, keys[6].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(2)), external: true)).thenReturn([keys[7].publicKey, keys[8].publicKey])
        }

        try! manager.fillGap()
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(1)..<UInt32(3)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: true))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(2)), external: equal(to: true))

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
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(3)..<UInt32(4)), external: false)).thenReturn([keys[5].publicKey])
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(2)..<UInt32(3)), external: true)).thenReturn([keys[6].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(1)), external: false)).thenReturn([keys[7].publicKey])
            when(mock.publicKeys(account: 1, indices: equal(to: UInt32(0)..<UInt32(1)), external: true)).thenReturn([keys[9].publicKey])
        }

        try! manager.fillGap()
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(3)..<UInt32(4)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 0), indices: equal(to: UInt32(2)..<UInt32(3)), external: equal(to: true))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(1)), external: equal(to: false))
        verify(mockHDWallet).publicKeys(account: equal(to: 1), indices: equal(to: UInt32(0)..<UInt32(1)), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[5].publicKey]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[6].publicKey]))
    }

    func testAddKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
        ]

        manager.addKeys(keys: keys)
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

    func testPublicKey_byPath_ExistsInStorage() {
        let key = getPublicKey(withAccount: 10, index: 20, chain: .internal)

        stub(mockStorage) { mock in
            when(mock.publicKey(byPath: equal(to: "10/0/20"))).thenReturn(key)
        }

        XCTAssertEqual(try! manager.publicKey(byPath: "10/0/20"), key)
        verify(mockStorage).publicKey(byPath: equal(to: "10/0/20"))
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testPublicKey_byPath_DoesNotExistsInStorage() {
        let key = getPublicKey(withAccount: 10, index: 20, chain: .external)

        stub(mockStorage) { mock in
            when(mock.publicKey(byPath: equal(to: "10/1/20"))).thenReturn(nil)
        }
        stub(mockHDWallet) { mock in
            when(mock.publicKey(account: 10, index: 20, external: true)).thenReturn(key)
        }

        XCTAssertEqual(try! manager.publicKey(byPath: "10/1/20"), key)
        verify(mockStorage).publicKey(byPath: equal(to: "10/1/20"))
        verify(mockHDWallet).publicKey(account: 10, index: 20, external: true)
    }

    func testPublicKey_byPath_InvalidPath() {
        do {
            _ = try manager.publicKey(byPath: "0/0")
            XCTFail("Expected exception")
        } catch let error as PublicKeyManager.PublicKeyManagerError {
            XCTAssertEqual(error, .invalidPath)
        } catch {
            XCTFail("Unexpected exception")
        }
    }

    func testFilterElements() {
        let publicKeys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 3, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .external)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn(publicKeys)
        }

        var elements = [Data]()
        stub(mockRestoreKeyConverter) { mock in
            for publicKey in publicKeys {
                let newElements = [publicKey.keyHash]
                elements.append(contentsOf: newElements)
                when(mock).bloomFilterElements(publicKey: equal(to: publicKey)).thenReturn(newElements)
            }
        }

        XCTAssertEqual(manager.filterElements(), elements)
    }

    private func getPublicKey(withAccount account: Int, index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(account: account, index: index, external: chain == .external)
        return PublicKey(withAccount: account, index: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }

}
