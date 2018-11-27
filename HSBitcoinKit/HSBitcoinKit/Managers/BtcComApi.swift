import Foundation
import RxSwift

class BtcComApi {
    private let apiManager: ApiManager

    init(network: INetwork, logger: Logger? = nil) {
        let url: String

        switch network {
        case is BitcoinMainNet: url = "https://chain.api.btc.com/v3"
        case is BitcoinTestNet: url = "https://tchain.api.btc.com/v3"
        case is BitcoinCashMainNet: url = "https://bch-chain.api.btc.com/v3"
        case is BitcoinCashTestNet: url = "https://bch-tchain.api.btc.com/v3"
        default: url = "https://tchain.api.btc.com/v3"
        }

        apiManager = ApiManager(apiUrl: url, logger: logger)
    }

    private func handleRequest(address: String, page: Int = 1, result: Set<BlockResponse> = []) -> Observable<Set<BlockResponse>> {
        return requestTransactions(address: address, page: page)
                .flatMap { [weak self] (response: ApiAddressTxResponse) -> Observable<Set<BlockResponse>> in
                    let union = result.union(response.list)
                    if response.totalCount > response.page * response.pageSize {
                        return self?.handleRequest(address: address, page: response.page + 1, result: union) ?? Observable.just(union)
                    }
                    return Observable.just(union)
                 }
    }

    private func requestTransactions(address: String, page: Int) -> Observable<ApiAddressTxResponse> {
        return observable(address: address, page: page).flatMap { [weak self] (response: ApiAddressTxResponse) -> Observable<ApiAddressTxResponse> in
            let emptyBlockHashes = response.list.filter { $0.hash.isEmpty }
            var observable: Observable<ApiAddressTxResponse>?
            if !emptyBlockHashes.isEmpty {
                observable = self?.reloadEmptyHashes(response, emptyBlockHashes: emptyBlockHashes)
            }
            return observable ?? Observable.just(response)
        }
    }

    private func observable(address: String, page: Int) -> Observable<ApiAddressTxResponse> {
        return apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/address/\(address)/tx", parameters: ["page": page]), mapper: { json -> ApiAddressTxResponse? in
            guard let response = json as? [String: Any] else {
                return nil
            }
            if let data = response["data"] as? [String: Any] {
                let totalCount = (data["total_count"] as? Int) ?? 0
                let page = (data["page"] as? Int) ?? 0
                let pageSize = (data["pagesize"] as? Int) ?? 1
                var list = Set<BlockResponse>()

                if let listData = data["list"] as? [[String: Any]] {
                    listData.forEach { dictionary in
                        if let hash = dictionary["block_hash"] as? String, let height = dictionary["block_height"] as? Int, height > 0 {
                            list.insert(BlockResponse(hash: hash, height: height))
                        }
                    }
                }
                return ApiAddressTxResponse(totalCount: totalCount, page: page, pageSize: pageSize, list: list)
            }
            return ApiAddressTxResponse()
        })
    }

    private func reloadEmptyHashes(_ apiAddressTxResponse: ApiAddressTxResponse, emptyBlockHashes: Set<BlockResponse>) -> Observable<ApiAddressTxResponse> {
        let listOfHeights = Array<String>(Set<String>(emptyBlockHashes.map { String($0.height) })).joined(separator: ",")

        return observable(listOfHeights).map { (set: Set<BlockResponse>) -> ApiAddressTxResponse  in
            let newList = apiAddressTxResponse.list.subtracting(emptyBlockHashes).union(set)
            let newTxResponse = ApiAddressTxResponse(totalCount: apiAddressTxResponse.totalCount, page: apiAddressTxResponse.page, pageSize: apiAddressTxResponse.pageSize, list: newList)

            return newTxResponse
        }
    }

    private func observable(_ listOfHeights: String) -> Observable<Set<BlockResponse>> {
        return apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/block/\(listOfHeights)", parameters: nil), mapper: {json -> Set<BlockResponse>? in
            guard let response = json as? [String: Any] else {
                return nil
            }
            var set = Set<BlockResponse>()
            var data = [[String: Any]]()
            if let dataObject = response["data"] as? [String: Any] {
                data.append(dataObject)
            } else if let dataArray = response["data"] as? [[String: Any]] {
                data.append(contentsOf: dataArray)
            }
            data.forEach { dictionary in
                if let hash = dictionary["hash"] as? String, let height = dictionary["height"] as? Int, height > 0 {
                    set.insert(BlockResponse(hash: hash, height: height))
                }
            }
            return set
        })
    }

}

extension BtcComApi: IInitialSyncApi {

    func getBlockHashes(address: String) -> Observable<Set<BlockResponse>> {
        return handleRequest(address: address)
    }

}

class ApiAddressTxResponse {
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let list: Set<BlockResponse>

    init(totalCount: Int = 0, page: Int = 0, pageSize: Int = 1, list: Set<BlockResponse> = Set()) {
        self.totalCount = totalCount
        self.page = page
        self.pageSize = pageSize
        self.list = list
    }

}
