import XCTest
import Cuckoo
import RxSwift
import RxBlocking

@testable import HSBitcoinKit


class BlockDiscoveryBatchTest: XCTestCase {

    private var mockNetwork: MockINetwork!
    private var mockWallet: MockIHDWallet!
    private var mockBlockHashFetcher: MockIBlockHashFetcher!

    private var blockDiscovery: BlockDiscoveryBatch!

    private let publicKeys = [PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 1, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 2, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 3, external: true, hdPublicKeyData: Data()),
                              PublicKey(withAccount: 0, index: 4, external: true, hdPublicKeyData: Data()),
    ]

    override func setUp() {
        super.setUp()

        mockNetwork = MockINetwork()
        mockWallet = MockIHDWallet()
        mockBlockHashFetcher = MockIBlockHashFetcher()

        stub(mockWallet) {mock in
            when(mock.gapLimit.get).thenReturn(3)
        }

        stub(mockNetwork) {mock in
            when(mock.checkpointBlock.get).thenReturn(Block(withHeaderHash: Data(), height: 50000))
        }

        blockDiscovery = BlockDiscoveryBatch(network: mockNetwork, wallet: mockWallet, blockHashFetcher: mockBlockHashFetcher, logger: nil)
    }

    override func tearDown() {
        mockWallet = nil
        mockNetwork = nil
        mockBlockHashFetcher = nil

        blockDiscovery = nil

        super.tearDown()
    }

    func testFetchFromApi() {
        stub(mockWallet) { mock in
            for i in 0..<5 {
                when(mock.publicKey(account: 0, index: i, external: true)).thenReturn(publicKeys[i])
            }
        }

        let lastUsedIndex = 1
        let blockHash = BlockHash(headerHashReversedHex: "1234", height: 1234, sequence: 0)!

        stub(mockBlockHashFetcher) { mock in
            when(mock.getBlockHashes(publicKeys: equal(to: [publicKeys[0], publicKeys[1], publicKeys[2]]))).thenReturn(Observable.just(([blockHash], lastUsedIndex)))
            when(mock.getBlockHashes(publicKeys: equal(to: [publicKeys[3], publicKeys[4]]))).thenReturn(Observable.just(([], -1)))
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
