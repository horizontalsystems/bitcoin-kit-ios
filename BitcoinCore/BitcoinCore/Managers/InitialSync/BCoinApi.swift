import RxSwift
import ObjectMapper

class BCoinApi {
    private let apiManager: ApiManager

    init(url: String, logger: Logger? = nil) {
        apiManager = ApiManager(apiUrl: url, logger: logger)
    }

}

extension BCoinApi: IBCoinApi {

    func getTransactions(addresses: [String]) -> Observable<[TransactionItem]> {
        let parameters: [String: Any] = [
            "addresses": addresses
        ]

        let httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        let request = apiManager.request(withMethod: .post, path: "/tx/address", httpBody: httpBody)
        return apiManager.observable(forRequest: request)
    }

    class TransactionItem: ImmutableMappable {
        let blockHash: String
        let blockHeight: Int
        let txOutputs: [TransactionOutputItem]

        init(hash: String, height: Int, txOutputs: [TransactionOutputItem]) {
            self.blockHash = hash
            self.blockHeight = height
            self.txOutputs = txOutputs
        }

        required init(map: Map) throws {
            blockHash = try map.value("block")
            blockHeight = try map.value("height")
            txOutputs = try map.value("outputs")
        }

        static func ==(lhs: TransactionItem, rhs: TransactionItem) -> Bool {
            return lhs.blockHash == rhs.blockHash && lhs.blockHeight == rhs.blockHeight
        }

    }

    class TransactionOutputItem: ImmutableMappable {
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

}
