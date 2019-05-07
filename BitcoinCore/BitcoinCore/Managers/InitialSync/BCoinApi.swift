import RxSwift
import ObjectMapper

public class BCoinApi {
    private let apiManager: ApiManager

    public init(url: String, logger: Logger? = nil) {
        apiManager = ApiManager(apiUrl: url, logger: logger)
    }

}

extension BCoinApi: ISyncTransactionApi {

    public func getTransactions(addresses: [String]) -> Observable<[SyncTransactionItem]> {
        let parameters: [String: Any] = [
            "addresses": addresses
        ]

        let httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        let request = apiManager.request(withMethod: .post, path: "/tx/address", httpBody: httpBody)
        return apiManager.observable(forRequest: request)
    }

}
