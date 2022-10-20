import RxSwift
import ObjectMapper
import Alamofire
import HsToolKit

public class BCoinApi {
    private let url: String
    private let networkManager: NetworkManager

    public init(url: String, logger: Logger? = nil) {
        self.url = url
        networkManager = NetworkManager(logger: logger)
    }

}

extension BCoinApi: ISyncTransactionApi {

    public func getTransactions(addresses: [String]) -> Single<[SyncTransactionItem]> {
        let parameters: Parameters = [
            "addresses": addresses
        ]
        let path = "/tx/address"

        let request = networkManager.session.request(url + path, method: .post, parameters: parameters, encoding: JSONEncoding.default)
        return networkManager.single(request: request)
    }

}
