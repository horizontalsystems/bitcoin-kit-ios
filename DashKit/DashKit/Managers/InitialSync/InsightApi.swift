import RxSwift
import ObjectMapper
import BitcoinCore

class InsightApi {
    private let apiManager: ApiManager

    init(url: String, logger: Logger? = nil) {
        apiManager = ApiManager(apiUrl: url, logger: logger)
    }

}

extension InsightApi: ISyncTransactionApi {

    func getTransactions(addresses: [String]) -> Observable<[SyncTransactionItem]> {
        let joinedAddresses = addresses.joined(separator: ",")

        let request = apiManager.request(withMethod: .get, path: "/addrs/\(joinedAddresses)/txs")
        let observable: Observable<InsightResponseItem> = apiManager.observable(forRequest: request)
        return observable.map { $0.transactionItems.map { $0 as SyncTransactionItem } }
    }

    class InsightResponseItem: ImmutableMappable {
        public let totalItems: Int
        public let from: Int
        public let to: Int
        public let transactionItems: [InsightTransactionItem]

        public init(totalItems: Int, from: Int, to: Int, transactionItems: [InsightTransactionItem]) {
            self.totalItems = totalItems
            self.from = from
            self.to = to
            self.transactionItems = transactionItems
        }

        required public init(map: Map) throws {
            totalItems = try map.value("totalItems")
            from = try map.value("from")
            to = try map.value("to")
            transactionItems = try map.value("items")
        }

    }

    class InsightTransactionItem: SyncTransactionItem {

        required init(map: Map) throws {
            let blockHash: String = try map.value("blockhash")
            let blockHeight: Int = try map.value("blockheight")
            let txOutputs: [InsightTransactionOutputItem] = try map.value("vout")
            super.init(hash: blockHash, height: blockHeight, txOutputs: txOutputs.map { $0 as SyncTransactionOutputItem })
        }

    }

    class InsightTransactionOutputItem: SyncTransactionOutputItem {
        required init(map: Map) throws {
            let script: String = try map.value("scriptPubKey.hex")
            let address: [String] = try map.value("scriptPubKey.addresses")
            super.init(script: script, address: address.joined())
        }

    }

}
