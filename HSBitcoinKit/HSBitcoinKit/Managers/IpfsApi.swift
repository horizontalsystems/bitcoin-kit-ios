import Foundation
import RxSwift

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class IpfsApi {
    private let apiKey = "Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz"

    private let apiManager: ApiManager
    private let resource: String

    init(resource: String, apiProvider: IApiConfigProvider, logger: Logger? = nil) {
        self.resource = resource
        apiManager = ApiManager(apiUrl: apiProvider.apiUrl + "/\(apiKey)", logger: logger)
    }

}

extension IpfsApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        return apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/io-hs/data/blockchain/\(resource)/estimatefee/index.json"))
    }

}
