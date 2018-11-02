import XCTest
import Cuckoo
import RxSwift
@testable import HSBitcoinKit

class BTCApiSyncerTests: XCTestCase {
    private let disposeBag = DisposeBag()
    private var publicKey: PublicKey!
    private var apiRequester: MockIApiRequester!
    private var addressSelector: MockIAddressSelector!

    private var apiSyncer: BTCApiSyncer!

    override func setUp() {
        super.setUp()
        apiRequester = MockIApiRequester()
        addressSelector = MockIAddressSelector()
        publicKey = PublicKey()

        stub(apiRequester) { mock in
            when(mock.requestTransactions(address: any(), page: any())).thenReturn(Observable.empty())
        }
        stub(addressSelector) { mock in
            when(mock.getAddressVariants(publicKey: any())).thenReturn(["base58-addr", "publicKeyHex", "pkhsh-addr"])
        }

        apiSyncer = BTCApiSyncer(apiRequester: apiRequester, addressSelector: addressSelector)
    }

    override func tearDown() {
        publicKey = nil
        apiRequester = nil
        addressSelector = nil

        apiSyncer = nil
        super.tearDown()
    }

    func testRequestBTC() {
        _ = apiSyncer.getBlockHashes(publicKey: publicKey)

        verify(apiRequester, times(1)).requestTransactions(address: "base58-addr", page: 1)
        verify(apiRequester, times(1)).requestTransactions(address: "publicKeyHex", page: 1)
        verify(apiRequester, times(1)).requestTransactions(address: "pkhsh-addr", page: 1)
        verifyNoMoreInteractions(apiRequester)
    }

    func testRequestBCH() {
        stub(addressSelector) { mock in
            when(mock.getAddressVariants(publicKey: any())).thenReturn(["base58-addr"])
        }

        _ = apiSyncer.getBlockHashes(publicKey: publicKey)

        verify(apiRequester, times(1)).requestTransactions(address: "base58-addr", page: 1)
        verifyNoMoreInteractions(apiRequester)
    }

    func testSinglePageResponse() {
        var expectedBlockResponse = [BlockResponse]()
        for i in 1...4 {
            expectedBlockResponse.append(BlockResponse(hash: "block\(i)", height: i))
        }
        stub(apiRequester) { mock in
            when(mock.requestTransactions(address: "base58-addr", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 2, page: 1, pageSize: 50, list: [expectedBlockResponse[0], expectedBlockResponse[1]])))
            when(mock.requestTransactions(address: "publicKeyHex", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 2, page: 1, pageSize: 50, list: [expectedBlockResponse[1], expectedBlockResponse[2]])))
            when(mock.requestTransactions(address: "pkhsh-addr", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 2, page: 1, pageSize: 50, list: [expectedBlockResponse[0], expectedBlockResponse[3]])))
        }
        _ = apiSyncer.getBlockHashes(publicKey: publicKey).subscribe(onNext: { response in
            let sortedResponse = response.sorted { response, response2 in response.height < response2.height }

            if response.isEmpty || !sortedResponse.elementsEqual(expectedBlockResponse) {
                XCTFail("Wrong response!")
            }
        })
    }

    func testMultiPageResponse() {
        var expectedBlockResponse = [BlockResponse]()
        for i in 1...7 {
            expectedBlockResponse.append(BlockResponse(hash: "block\(i)", height: i))
        }
        stub(apiRequester) { mock in
            when(mock.requestTransactions(address: "base58-addr", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 5, page: 1, pageSize: 2, list: [expectedBlockResponse[0], expectedBlockResponse[1]])))
            when(mock.requestTransactions(address: "base58-addr", page: 2)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 5, page: 2, pageSize: 2, list: [expectedBlockResponse[2], expectedBlockResponse[3]])))
            when(mock.requestTransactions(address: "base58-addr", page: 3)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 5, page: 3, pageSize: 2, list: [expectedBlockResponse[6]])))
            when(mock.requestTransactions(address: "publicKeyHex", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 3, page: 1, pageSize: 50, list: [expectedBlockResponse[4], expectedBlockResponse[3], expectedBlockResponse[5]])))
            when(mock.requestTransactions(address: "pkhsh-addr", page: 1)).thenReturn(Observable.just(ApiAddressTxResponse(totalCount: 2, page: 1, pageSize: 50, list: [expectedBlockResponse[0], expectedBlockResponse[3]])))
        }
        _ = apiSyncer.getBlockHashes(publicKey: publicKey).subscribe(onNext: { response in
            let sortedResponse = response.sorted { response, response2 in response.height < response2.height }

            if response.isEmpty || !sortedResponse.elementsEqual(expectedBlockResponse) {
                XCTFail("Wrong response!")
            }

        })
        verify(apiRequester, times(1)).requestTransactions(address: "base58-addr", page: 1) //base 58
        verify(apiRequester, times(1)).requestTransactions(address: "base58-addr", page: 2) //base 58
        verify(apiRequester, times(1)).requestTransactions(address: "base58-addr", page: 3) //base 58
        verify(apiRequester, times(1)).requestTransactions(address: "publicKeyHex", page: 1) //pkh for segwit
        verify(apiRequester, times(1)).requestTransactions(address: "pkhsh-addr", page: 1) //p2wpkh (sh)
    }

    func testError() {
        stub(apiRequester) { mock in
            when(mock.requestTransactions(address: "base58-addr", page: 1)).thenReturn(Observable.error(BTCApiSyncer.SyncerError.syncError))
        }
        _ = apiSyncer.getBlockHashes(publicKey: publicKey).subscribe(onNext: { _ in XCTFail("Must be error!")}, onError: { error in
            if let error = error as? BTCApiSyncer.SyncerError {
                XCTAssertEqual(error, BTCApiSyncer.SyncerError.syncError)
            } else {
                XCTFail("Wrong error!")
            }
        })
    }
}
