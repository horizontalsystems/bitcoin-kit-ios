import Foundation
import RxSwift
import ObjectMapper

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class IpfsApi {
    private let apiKey = "Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz"

    private let apiManager: ApiManager

    private var coinType: String
    private let networkType: String

    init(network: INetwork, apiProvider: IApiConfigProvider, logger: Logger? = nil) {
        switch network {
        case is BitcoinCashMainNet, is BitcoinCashTestNet: coinType = "BCH"
        case is DashMainNet, is DashTestNet: coinType = "DASH"
        default: coinType = "BTC"
        }

        switch network {
        case is BitcoinTestNet, is BitcoinCashTestNet, is DashTestNet: networkType = "testnet"
        default: networkType = ""
        }

        apiManager = ApiManager(apiUrl: apiProvider.apiUrl + "/\(apiKey)", logger: logger)
    }

}

extension IpfsApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        let observable: Observable<FeeRateResponse> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/io-hs/data/blockchain/\(coinType)/\(networkType)/estimatefee/index.json"))

        return observable.map { FeeRate(dateInterval: $0.dateInterval, date: $0.date, low: Double($0.lowPriority) ?? 0, medium: Double($0.mediumPriority) ?? 0, high: Double($0.highPriority) ?? 0)}
    }

}

struct FeeRateResponse: ImmutableMappable {
    let lowPriority: String
    let mediumPriority: String
    let highPriority: String
    let date: String
    let dateInterval: Int

    init(map: Map) throws {
        lowPriority = try map.value("low_priority")
        mediumPriority = try map.value("medium_priority")
        highPriority = try map.value("high_priority")

        date = try map.value("date_str")
        dateInterval = try map.value("date")
    }
}

