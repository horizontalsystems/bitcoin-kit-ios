//import XCTest
//import Cuckoo
//import RxSwift
//import RxBlocking
//
//@testable import BitcoinCore
//
//class BlockHashFetcherTests: XCTestCase {
//
//    private var mockApiManager: MockIBCoinApi!
//    private var mockAddressSelector: MockIAddressSelector!
//    private var mockBlockHashFetcherHelper: MockIBlockHashFetcherHelper!
//
//    private var blockHashFetcher: BlockHashFetcher!
//
//    private let addresses = [["0_0", "0_1"],
//                             ["1_0", "1_1"],
//                             ["2_0", "2_1"]]
//
//    private let publicKeys = [PublicKey(withAccount: 0, index: 0, external: true, hdPublicKeyData: Data()),
//                      PublicKey(withAccount: 0, index: 1, external: true, hdPublicKeyData: Data()),
//                      PublicKey(withAccount: 0, index: 2, external: true, hdPublicKeyData: Data()),
//    ]
//
//    override func setUp() {
//        super.setUp()
//
//        mockApiManager = MockIBCoinApi()
//        mockAddressSelector = MockIAddressSelector()
//        mockBlockHashFetcherHelper = MockIBlockHashFetcherHelper()
//
//        stub(mockAddressSelector) {mock in
//            when(mock.getAddressVariants(publicKey: equal(to: publicKeys[0]))).thenReturn(addresses[0])
//            when(mock.getAddressVariants(publicKey: equal(to: publicKeys[1]))).thenReturn(addresses[1])
//            when(mock.getAddressVariants(publicKey: equal(to: publicKeys[2]))).thenReturn(addresses[2])
//        }
//
//        blockHashFetcher = BlockHashFetcher(addressSelector: mockAddressSelector, apiManager: mockApiManager, helper: mockBlockHashFetcherHelper)
//    }
//
//    override func tearDown() {
//        mockApiManager = nil
//        mockAddressSelector = nil
//        mockBlockHashFetcherHelper = nil
//
//        blockHashFetcher = nil
//
//        super.tearDown()
//    }
//
//    func testEmptyBlockHashes() {
//        stub(mockApiManager) { mock in
//            when(mock.getTransactions(addresses: equal(to: addresses.flatMap { $0 }))).thenReturn(Observable.just([]))
//        }
//
//        let resultObservable = blockHashFetcher.getBlockHashes(publicKeys: publicKeys)
//        do{
//            let result = try resultObservable.toBlocking().first()
//            XCTAssertTrue(result!.responses.isEmpty)
//            XCTAssertEqual(-1, result!.lastUsedIndex)
//        } catch {
//            XCTFail("Catch error!")
//        }
//    }
//
//    func testNonEmptyBlockHashes() {
//        let responses = [BCoinApi.TransactionItem(hash: "1234", height: 1234, txOutputs: []),
//                         BCoinApi.TransactionItem(hash: "5678", height: 5678, txOutputs: [])]
//
//        stub(mockApiManager) { mock in
//            when(mock.getTransactions(addresses: equal(to: addresses.flatMap { $0 }))).thenReturn(Observable.just(responses))
//        }
//        let lastUsedIndex = 1
//        stub(mockBlockHashFetcherHelper) { mock in
//            when(mock.lastUsedIndex(addresses: equal(to: addresses), outputs: any())).thenReturn(lastUsedIndex)
//        }
//
//        let resultObservable = blockHashFetcher.getBlockHashes(publicKeys: publicKeys)
//
//        do{
//            let result = try resultObservable.toBlocking().first()
//            XCTAssertEqual(2, result!.responses.count)
//            XCTAssertEqual("1234", result!.responses[0].headerHashReversedHex)
//            XCTAssertEqual(1234, result!.responses[0].height)
//            XCTAssertEqual("5678", result!.responses[1].headerHashReversedHex)
//            XCTAssertEqual(5678, result!.responses[1].height)
//            XCTAssertEqual(lastUsedIndex, result!.lastUsedIndex)
//        } catch {
//            XCTFail("Catch error!")
//        }
//    }
//
//}
