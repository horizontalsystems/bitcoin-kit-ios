import XCTest
import Cuckoo
import RxSwift
import RxBlocking

@testable import BitcoinCore


class BlockDiscoveryBatchTest: XCTestCase {

    private var mockWallet: MockIHDWallet!
    private var mockBlockHashFetcher: MockIBlockHashFetcher!

    private let checkpoint = TestData.checkpoint

    private var blockDiscovery: BlockDiscoveryBatch!

    private let externalPublicKeys = [
        PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 1, external: true, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 2, external: true, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 3, external: true, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 4, external: true, hdPublicKeyData: Data())
    ]

    private let internalPublicKeys = [
        PublicKey(withAccount: 0, index: 0, external: false, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 1, external: false, hdPublicKeyData: Data()),
        PublicKey(withAccount: 0, index: 2, external: false, hdPublicKeyData: Data())
    ]

    override func setUp() {
        super.setUp()

        mockWallet = MockIHDWallet()
        mockBlockHashFetcher = MockIBlockHashFetcher()

        stub(mockWallet) {mock in
            when(mock.gapLimit.get).thenReturn(3)
        }

        blockDiscovery = BlockDiscoveryBatch(checkpoint: checkpoint, wallet: mockWallet, blockHashFetcher: mockBlockHashFetcher, logger: nil)
    }

    override func tearDown() {
        mockWallet = nil
        mockBlockHashFetcher = nil

        blockDiscovery = nil

        super.tearDown()
    }

    func testFetchFromApi() {
        stub(mockWallet) { mock in
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(3)), external: true)).thenReturn(Array(externalPublicKeys[0..<3]))
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(3)), external: false)).thenReturn(Array(internalPublicKeys[0..<3]))
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(3)..<UInt32(5)), external: true)).thenReturn(Array(externalPublicKeys[3..<5]))
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(3)..<UInt32(3)), external: false)).thenReturn([])
        }

        let lastUsedIndex = 1
        let blockHash = BlockHash(headerHashReversedHex: "1234", height: 1234, sequence: 0)!

        stub(mockBlockHashFetcher) { mock in
            when(mock.getBlockHashes(
                    externalKeys: equal(to: [externalPublicKeys[0], externalPublicKeys[1], externalPublicKeys[2]]), internalKeys: equal(to: [internalPublicKeys[0], internalPublicKeys[1], internalPublicKeys[2]])
            )).thenReturn(Single.just(
                    BlockHashesResponse(blockHashes: [blockHash], externalLastUsedIndex: lastUsedIndex, internalLastUsedIndex: -1)
            ))
            when(mock.getBlockHashes(
                    externalKeys: equal(to: [externalPublicKeys[3], externalPublicKeys[4]]), internalKeys: equal(to: [])
            )).thenReturn(Single.just(
                    BlockHashesResponse(blockHashes: [], externalLastUsedIndex: -1, internalLastUsedIndex: -1)
            ))
        }

        let resultObservable = blockDiscovery.discoverBlockHashes(account: 0)
        do{
            let result = try resultObservable.toBlocking().first()
            XCTAssertEqual(externalPublicKeys + internalPublicKeys, result!.0)
            XCTAssertEqual([blockHash], result!.1)
        } catch {
            XCTFail("Catch error!")
        }
    }

}
