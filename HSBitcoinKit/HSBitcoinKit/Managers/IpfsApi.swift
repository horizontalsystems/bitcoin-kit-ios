import Foundation
import RxSwift
import ObjectMapper

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class IpfsApi {
    private let apiKey = "QmXTJZBMMRmBbPun6HFt3tmb3tfYF2usLPxFoacL7G5uMX"

    private let apiManager: ApiManager

    private var coinType: String

    init(network: INetwork, apiProvider: IApiConfigProvider, logger: Logger? = nil) {
        switch network {
        case is BitcoinCashMainNet, is BitcoinCashTestNet: coinType = "BCH"
        default: coinType = "BTC"
        }

        apiManager = ApiManager(apiUrl: apiProvider.apiUrl + "/\(apiKey)", logger: logger)
    }

}

extension IpfsApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        let coinType = self.coinType
        let observable: Observable<FeeRateData> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/blockchain/estimatefee/index.json"))
        return observable.map { feeRateData in
            if let data = feeRateData.data[coinType] as? [String: Any],
               let lowPriority = data["low_priority"] as? Double,
               let mediumPriority = data["medium_priority"] as? Double,
               let highPriority = data["high_priority"] as? Double
            {
                let rate = FeeRate()
                rate.lowPriority = lowPriority
                rate.mediumPriority = mediumPriority
                rate.highPriority = highPriority
                rate.date = feeRateData.date
                return rate
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
