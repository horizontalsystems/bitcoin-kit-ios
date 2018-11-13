import XCTest
import Cuckoo
import HSHDWalletKit
import RealmSwift
@testable import HSBitcoinKit

class BloomFilterManagerTests: XCTestCase {

    private var mockRealmFactory: MockIRealmFactory!
    private var mockFactory: MockIFactory!
    private var mockBloomFilterManagerDelegate: MockBloomFilterManagerDelegate!

    private var realm: Realm!
    private var hdWallet: IHDWallet!
    private var bloomFilter: BloomFilter!
    private var manager: BloomFilterManager!

    override func setUp() {
        super.setUp()

        mockRealmFactory = MockIRealmFactory()
        mockFactory = MockIFactory()
        mockBloomFilterManagerDelegate = MockBloomFilterManagerDelegate()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }
        stub(mockRealmFactory) {mock in
            when(mock.realm.get).thenReturn(realm)
        }

        stub(mockBloomFilterManagerDelegate) { mock in
            when(mock.bloomFilterUpdated(bloomFilter: any())).thenDoNothing()
        }

        bloomFilter = BloomFilter(elements: [Data(from: 9999999)])
        hdWallet = HDWallet(seed: Data(), coinType: UInt32(1), xPrivKey: UInt32(0x04358394), xPubKey: UInt32(0x043587cf))
        manager = BloomFilterManager(realmFactory: mockRealmFactory, factory: mockFactory)
        manager.delegate = mockBloomFilterManagerDelegate
    }

    override func tearDown() {
        mockRealmFactory = nil
        mockFactory = nil
        mockBloomFilterManagerDelegate = nil

        realm = nil
        hdWallet = nil
        bloomFilter = nil
        manager = nil

        super.tearDown()
    }

    func testRegenerateBloomFilter_PublicKeys() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .external),
        ]

        try! realm.write {
            realm.add(keys)
        }

        stub(mockFactory) { mock in
            when(mock).bloomFilter(withElements: any()).thenReturn(bloomFilter)
        }

        manager.regenerateBloomFilter()

        var expectedElements: [Data] = []
        for key in keys {
            expectedElements.append(key.keyHash)
            expectedElements.append(key.raw)
            expectedElements.append(key.scriptHashForP2WPKH)
        }

        verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
        verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
    }

    func testRegenerateBloomFilter_UnspentTransactions() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .external),
        ]

        let transactions = [TestData.p2wpkhTransaction, TestData.p2pkTransaction, TestData.p2pkhTransaction, TestData.p2shTransaction]

        try! realm.write {
            realm.add(keys)
            realm.add(transactions)
            transactions[0].outputs[0].publicKey = keys[0]
            transactions[1].outputs[0].publicKey = keys[1]
            transactions[2].outputs[0].publicKey = keys[1]
        }

        stub(mockFactory) { mock in
            when(mock).bloomFilter(withElements: any()).thenReturn(bloomFilter)
        }

        manager.regenerateBloomFilter()

        var expectedElements: [Data] = []
        for key in keys {
            expectedElements.append(key.keyHash)
            expectedElements.append(key.raw)
            expectedElements.append(key.scriptHashForP2WPKH)
        }
        expectedElements.append(transactions[0].dataHash + byteArrayLittleEndian(int: transactions[0].outputs[0].index))
        expectedElements.append(transactions[1].dataHash + byteArrayLittleEndian(int: transactions[1].outputs[0].index))

        verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
        verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
    }

    func testRegenerateBloomFilter_SpentTransactions() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .external),
        ]

        let firstBlock = TestData.firstBlock
        let secondBlock = TestData.secondBlock
        firstBlock.previousBlock = nil
        secondBlock.previousBlock = nil
        firstBlock.height = 890
        secondBlock.height = 1000

        let transactions = [TestData.p2wpkhTransaction, TestData.p2pkTransaction, TestData.p2pkhTransaction, TestData.p2shTransaction]

        let txInput1 = TransactionInput(withPreviousOutputTxReversedHex: "00000001111111", previousOutputIndex: 0, script: Data(), sequence: 0)
        let txInput2 = TransactionInput(withPreviousOutputTxReversedHex: "00000002222222", previousOutputIndex: 0, script: Data(), sequence: 0)
        txInput1.previousOutput = transactions[0].outputs[0]
        txInput2.previousOutput = transactions[1].outputs[0]
        let tx1 = Transaction(version: 0, inputs: [txInput1], outputs: [])
        let tx2 = Transaction(version: 0, inputs: [txInput2], outputs: [])
        tx1.block = firstBlock
        tx2.block = secondBlock

        try! realm.write {
            realm.add(keys)
            realm.add(firstBlock)
            realm.add(secondBlock)
            realm.add(transactions)
            realm.add(tx1)
            realm.add(tx2)

            transactions[0].outputs[0].publicKey = keys[0]
            transactions[1].outputs[0].publicKey = keys[1]
        }

        stub(mockFactory) { mock in
            when(mock).bloomFilter(withElements: any()).thenReturn(bloomFilter)
        }

        manager.regenerateBloomFilter()

        var expectedElements: [Data] = []
        for key in keys {
            expectedElements.append(key.keyHash)
            expectedElements.append(key.raw)
            expectedElements.append(key.scriptHashForP2WPKH)
        }
        // Only second transaction because the first one is in the block with height less than bestBlockHeight(1000) - 100
        expectedElements.append(transactions[1].dataHash + byteArrayLittleEndian(int: transactions[1].outputs[0].index))

        verify(mockFactory).bloomFilter(withElements: equal(to: expectedElements))
        verify(mockBloomFilterManagerDelegate).bloomFilterUpdated(bloomFilter: equal(to: bloomFilter, equalWhen: { $0.filter == $1.filter }))
    }

    func testRegenerateBloomFilter_NoElements() {
        manager.regenerateBloomFilter()
        verify(mockFactory, never()).bloomFilter(withElements: any())
        verify(mockBloomFilterManagerDelegate, never()).bloomFilterUpdated(bloomFilter: any())
    }

    func testRegenerateBloomFilter_NoNewElements() {
        let keys = [
            getPublicKey(withIndex: 0, chain: .external),
            getPublicKey(withIndex: 0, chain: .internal),
            getPublicKey(withIndex: 1, chain: .external),
        ]

        stub(mockFactory) { mock in
            when(mock).bloomFilter(withElements: any()).thenReturn(bloomFilter)
        }

        manager.regenerateBloomFilter()

        reset(mockBloomFilterManagerDelegate)
        stub(mockBloomFilterManagerDelegate) { mock in
            when(mock.bloomFilterUpdated(bloomFilter: any())).thenDoNothing()
        }

        manager.regenerateBloomFilter()
        verify(mockBloomFilterManagerDelegate, never()).bloomFilterUpdated(bloomFilter: any())
    }


    private func getPublicKey(withIndex index: Int, chain: HDWallet.Chain) -> PublicKey {
        let hdPrivKeyData = try! hdWallet.privateKeyData(index: index, external: chain == .external)
        return PublicKey(withIndex: index, external: chain == .external, hdPublicKeyData: hdPrivKeyData)
    }

    private func byteArrayLittleEndian(int: Int) -> [UInt8] {
        return [
            UInt8(int & 0x000000FF),
            UInt8((int & 0x0000FF00) >> 8),
            UInt8((int & 0x00FF0000) >> 16),
            UInt8((int & 0xFF000000) >> 24)
        ]
    }

}
