import Foundation
import RxSwift
import ObjectMapper

// https://ipfs.horizontalsystems.xyz/ipns/Qmd4Gv2YVPqs6dmSy1XEq7pQRSgLihqYKL2JjK7DMUFPVz/io-hs/data/blockchain/BTC/mainnet/estimatefee/index.json

class BcoinApi {
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

extension BcoinApi: IInitialSyncApi {

    func getBlockHashes(address: String) -> Observable<Set<BlockResponse>> {
        let observable: Observable<[BcoinBlockResponse]> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/tx/address/\(address)"))

        return observable.map { array in
            let blockResponseArray = array.map { bcoinResponse in
                BlockResponse(hash: bcoinResponse.hash, height: bcoinResponse.height)
            }
            return Set(blockResponseArray)
        }
    }

}

extension BcoinApi: IFeeRateApi {

    func getFeeRate() -> Observable<FeeRate> {
        let observable: Observable<FeeRateResponse> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/io-hs/data/blockchain/\(coinType)/\(networkType)/estimatefee/index.json"))

        return observable.map { FeeRate(dateInterval: $0.dateInterval, date: $0.date, low: Double($0.lowPriority) ?? 0, medium: Double($0.mediumPriority) ?? 0, high: Double($0.highPriority) ?? 0)}
    }

}

struct BcoinBlockResponse: ImmutableMappable, Hashable {
    let hash: String
    let height: Int

    init(hash: String, height: Int) {
        self.hash = hash
        self.height = height
    }

    init(map: Map) throws {
        hash = try map.value("block")
        height = try map.value("height")
    }

    static func ==(lhs: BcoinBlockResponse, rhs: BcoinBlockResponse) -> Bool {
        return lhs.height == rhs.height && lhs.hash == rhs.hash
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

