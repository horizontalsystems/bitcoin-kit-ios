import RxSwift
import ObjectMapper

class BCoinApiManager {
    private let url: String
    private let apiManager: ApiManager

    init(network: INetwork, logger: Logger? = nil) {
        switch network {
        case is BitcoinMainNet: url = "https://btc.horizontalsystems.xyz/apg"
        case is BitcoinTestNet: url = "http://btc-testnet.horizontalsystems.xyz/apg"
        case is BitcoinCashMainNet: url = "https://bch.horizontalsystems.xyz/apg"
        case is BitcoinCashTestNet: url = "http://bch-testnet.horizontalsystems.xyz/apg"
        default: url = "http://btc-testnet.horizontalsystems.xyz/apg"
        }

        apiManager = ApiManager(apiUrl: url, logger: logger)
    }

}

extension BCoinApiManager: IBCoinApiManager {

    func getTransactions(addresses: [String]) -> Observable<[BCoinTransactionResponse]> {
        let parameters: [String: Any] = [
            "addresses": addresses
        ]

        let httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        let request = apiManager.request(withMethod: .post, path: "/tx/address", httpBody: httpBody)
        return apiManager.observable(forRequest: request)
    }

}

class BCoinTransactionResponse: ImmutableMappable {
    let blockHash: String
    let blockHeight: Int
    let txOutputs: [BCoinTransactionOutput]

    init(hash: String, height: Int, txOutputs: [BCoinTransactionOutput]) {
        self.blockHash = hash
        self.blockHeight = height
        self.txOutputs = txOutputs
    }

    required init(map: Map) throws {
        blockHash = try map.value("block")
        blockHeight = try map.value("height")
        txOutputs = try map.value("outputs")
    }

    static func ==(lhs: BCoinTransactionResponse, rhs: BCoinTransactionResponse) -> Bool {
        return lhs.blockHash == rhs.blockHash && lhs.blockHeight == rhs.blockHeight
    }

}

class BCoinTransactionOutput: ImmutableMappable {
    let script: String
    let address: String

    init(script: String, address: String) {
        self.script = script
        self.address = address
    }

    required init(map: Map) throws {
        script = try map.value("script")
        address = try map.value("address")
    }

}
