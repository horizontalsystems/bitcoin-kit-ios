import Foundation
import RxSwift

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class IpfsApi {
    private let apiKey = "Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz"

    private let apiManager: ApiManager

    private var coinType: String
    private let networkType: String

    init(network: INetwork, apiProvider: IApiConfigProvider, logger: Logger? = nil) {
        switch network {
        case is BitcoinCashMainNet, is BitcoinCashTestNet: coinType = "BCH"
        default: coinType = "BTC"
        }

        switch network {
        case is BitcoinTestNet, is BitcoinCashTestNet: networkType = "testnet"
        default: networkType = ""
        }

        apiManager = ApiManager(apiUrl: apiProvider.apiUrl + "/\(apiKey)", logger: logger)
    }

}

extension IpfsApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        return apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/io-hs/data/blockchain/\(coinType)/\(networkType)/estimatefee/index.json"))
    }

}
