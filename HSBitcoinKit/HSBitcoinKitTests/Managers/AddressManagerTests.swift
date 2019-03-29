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
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 3, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .external)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn(publicKeys)
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: publicKeys[0]))).thenReturn(true)
        }

        let changePublicKey = try! manager.changePublicKey()
        XCTAssertEqual(changePublicKey.keyHash, publicKeys[3].keyHash)
    }

    func testChangePublicKey_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withAccount: 0, index: 0, chain: .internal)

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([publicKey])
            when(mock.hasOutputs(ofPublicKey: equal(to: publicKey))).thenReturn(true)
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
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 3, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .external)
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn(publicKeys)
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: publicKeys[0]))).thenReturn(true)
        }

        let address = LegacyAddress(type: .pubKeyHash, keyHash: publicKeys[3].keyHash, base58: "receiveAddress")
        stub(mockAddressConverter) { mock in
            when(mock.convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))).thenReturn(address)
        }

        XCTAssertEqual(try? manager.receiveAddress(), address.stringValue)
        verify(mockAddressConverter).convert(keyHash: equal(to: publicKeys[3].keyHash), type: equal(to: ScriptType.p2pkh))
    }

    func testReceiveAddress_NoUnusedPublicKey() {
        let publicKey =  getPublicKey(withAccount: 0, index: 0, chain: .external)

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([publicKey])
            when(mock.hasOutputs(ofPublicKey: equal(to: publicKey))).thenReturn(true)
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
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 1, index: 0, chain: .internal),
            getPublicKey(withAccount: 1, index: 1, chain: .internal),
            getPublicKey(withAccount: 1, index: 0, chain: .external),
            getPublicKey(withAccount: 1, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0], keys[1]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[5])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[6])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[7])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[8])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 1), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 1), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[2]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[3], keys[4]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[5], keys[6]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[7], keys[8]]))
    }

    func testFillGap_NoUsedKey() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([])
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[0])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[2])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[3])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))
        verify(mockHDWallet, never()).publicKey(account: equal(to: 1), index: any(), external: any())

        verify(mockStorage).add(publicKeys: equal(to: [keys[0], keys[1]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[2], keys[3]]))
    }

    func testFillGap_NoUnusedKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 1, index: 0, chain: .internal),
            getPublicKey(withAccount: 1, index: 1, chain: .internal),
            getPublicKey(withAccount: 1, index: 0, chain: .external),
            getPublicKey(withAccount: 1, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[1])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: false))).thenReturn(keys[2])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[3])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[4])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[5])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[6])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[7])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[8])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(2)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[1], keys[2]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[3], keys[4]]))
    }

    func testFillGap_NonSequentiallyUsedKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 0, index: 3, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .external),
            getPublicKey(withAccount: 1, index: 0, chain: .internal),
            getPublicKey(withAccount: 1, index: 1, chain: .internal),
            getPublicKey(withAccount: 1, index: 0, chain: .external),
            getPublicKey(withAccount: 1, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0], keys[1], keys[2], keys[3], keys[4]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[2]))).thenReturn(true)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[4]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(1)
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 3), external: equal(to: false))).thenReturn(keys[5])
            when(mock.publicKey(account: equal(to: 0), index: equal(to: 2), external: equal(to: true))).thenReturn(keys[6])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: false))).thenReturn(keys[7])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: false))).thenReturn(keys[8])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 0), external: equal(to: true))).thenReturn(keys[9])
            when(mock.publicKey(account: equal(to: 1), index: equal(to: 1), external: equal(to: true))).thenReturn(keys[10])
        }

        try! manager.fillGap()
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: false))
        verify(mockHDWallet, times(1)).publicKey(account: equal(to: 0), index: any(), external: equal(to: true))

        verify(mockStorage).add(publicKeys: equal(to: [keys[5]]))
        verify(mockStorage).add(publicKeys: equal(to: [keys[6]]))
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
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0], keys[1]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NoUnusedKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NonSequentiallyUsedKeys() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 0, index: 3, chain: .internal),
            getPublicKey(withAccount: 0, index: 2, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn([keys[0], keys[1], keys[2], keys[3], keys[4]])
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[0]))).thenReturn(true)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[2]))).thenReturn(true)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[4]))).thenReturn(true)
        }
        stub(mockHDWallet) { mock in
            when(mock.gapLimit.get).thenReturn(2)
        }

        XCTAssertEqual(manager.gapShifts(), true)
        verify(mockHDWallet, never()).publicKey(account: any(), index: any(), external: any())
    }

    func testGapShifts_NoShift() {
        let keys = [
            getPublicKey(withAccount: 0, index: 0, chain: .internal),
            getPublicKey(withAccount: 0, index: 1, chain: .internal),
            getPublicKey(withAccount: 0, index: 0, chain: .external),
            getPublicKey(withAccount: 0, index: 1, chain: .external),
            getPublicKey(withAccount: 0, index: 2, chain: .external),
        ]

        stub(mockStorage) { mock in
            when(mock.publicKeys()).thenReturn(keys)
            when(mock.hasOutputs(ofPublicKey: any())).thenReturn(false)
            when(mock.hasOutputs(ofPublicKey: equal(to: keys[2]))).thenReturn(true)
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
