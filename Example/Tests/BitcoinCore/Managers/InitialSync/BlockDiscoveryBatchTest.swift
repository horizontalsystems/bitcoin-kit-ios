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

    private let publicKeys = [PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 1, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 2, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 3, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 4, external: true, hdPublicKeyData: Data()),
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
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(0)..<UInt32(3)), external: true)).thenReturn(Array(publicKeys[0..<3]))
            when(mock.publicKeys(account: 0, indices: equal(to: UInt32(3)..<UInt32(5)), external: true)).thenReturn(Array(publicKeys[3..<5]))
        }

        let lastUsedIndex = 1
        let blockHash = BlockHash(headerHashReversedHex: "1234", height: 1234, sequence: 0)!

        stub(mockBlockHashFetcher) { mock in
            when(mock.getBlockHashes(publicKeys: equal(to: [publicKeys[0], publicKeys[1], publicKeys[2]]))).thenReturn(Single.just(([blockHash], lastUsedIndex)))
            when(mock.getBlockHashes(publicKeys: equal(to: [publicKeys[3], publicKeys[4]]))).thenReturn(Single.just(([], -1)))
        }

        let resultObservable = blockDiscovery.discoverBlockHashes(account: 0, external: true)
        do{
            let result = try resultObservable.toBlocking().first()
            XCTAssertEqual(publicKeys, result!.0)
            XCTAssertEqual([blockHash], result!.1)
        } catch {
            XCTFail("Catch error!")
        }
    }

}
