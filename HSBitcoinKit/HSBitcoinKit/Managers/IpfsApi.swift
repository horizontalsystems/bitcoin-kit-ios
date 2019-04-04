import Foundation
import RxSwift
import ObjectMapper

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class IpfsApi {
    private let apiKey = "QmXTJZBMMRmBbPun6HFt3tmb3tfYF2usLPxFoacL7G5uMX"

    private let apiManager: ApiManager
    private let resource: String

    init(resource: String, apiProvider: IApiConfigProvider, logger: Logger? = nil) {
        self.resource = resource
        apiManager = ApiManager(apiUrl: apiProvider.apiUrl + "/\(apiKey)", logger: logger)
    }

}

extension IpfsApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        let coin = self.resource
        let observable: Observable<FeeRateData> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/blockchain/estimatefee/index.json"))
        return observable.map { feeRateData in
            if let data = feeRateData.data[coin] as? [String: Any],
               let lowPriority = data["low_priority"] as? Int,
               let mediumPriority = data["medium_priority"] as? Int,
               let highPriority = data["high_priority"] as? Int
            {
                return FeeRate(low: lowPriority, medium: mediumPriority, high: highPriority, date: feeRateData.date)
            } else {
                return FeeRate.defaultFeeRate
            }
        }
    }

}

struct FeeRateData: ImmutableMappable {
    var data: [String: Any]
    var date: Date

    init(map: Map) throws {
        data = try map.value("rates")
        date = try map.value("time", using: DateTransform(unit: .milliseconds))
    }

}
