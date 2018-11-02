import Foundation
import RxSwift

class BTCApiSyncer: IApiSyncer {
    enum SyncerError: Error { case syncError }

    private let apiRequester: IApiRequester
    private let addressSelector: IAddressSelector

    init(apiRequester: IApiRequester, addressSelector: IAddressSelector) {
        self.apiRequester = apiRequester
        self.addressSelector = addressSelector
    }

    func getBlockHashes(publicKey: PublicKey) -> Observable<Set<BlockResponse>> {
        let addresses = addressSelector.getAddressVariants(publicKey: publicKey)
        return Observable.merge(addresses.map { handleRequest(address: $0) }).toArray().map { blockResponses in
            return Set(blockResponses.flatMap { Array($0) })
        }
    }

    private func handleRequest(address: String, page: Int = 1, result: Set<BlockResponse> = []) -> Observable<Set<BlockResponse>> {
        return apiRequester.requestTransactions(address: address, page: page)
                .flatMap { [weak self] (response: ApiAddressTxResponse) -> Observable<Set<BlockResponse>> in
                    let union = result.union(response.list)
                    if response.totalCount > response.page * response.pageSize {
                        return self?.handleRequest(address: address, page: response.page + 1, result: union) ?? Observable.just(union)
                    }
                    return Observable.just(union)
                 }
    }

}
