import RxSwift
import ObjectMapper
import Alamofire
import HsToolKit

public class InsightApi {
    private static let paginationLimit = 50

    private let url: String
    private let networkManager: NetworkManager

    public init(url: String, logger: Logger? = nil) {
        self.url = url
        networkManager = NetworkManager(logger: logger)
    }

}

extension InsightApi: ISyncTransactionApi {

    public func getTransactions(addresses: [String]) -> Single<[SyncTransactionItem]> {
        let joinedAddresses = addresses.joined(separator: ",")

        return getTransactionsRecursive(addresses: joinedAddresses)
    }

    private func getTransactionsRecursive(addresses: String, from: Int = 0, transactions: [SyncTransactionItem] = []) -> Single<[SyncTransactionItem]> {
        getTransactions(addresses: addresses, from: from).flatMap { [weak self] result -> Single<[SyncTransactionItem]> in
            let resultTransactions = transactions + result.transactionItems.map { $0 as SyncTransactionItem }

            let finishSingle = Single.just(resultTransactions)
            if result.totalItems <= result.to {
                return finishSingle
            } else {
                return self?.getTransactionsRecursive(addresses: addresses, from: result.to, transactions: resultTransactions) ?? finishSingle
            }
        }
    }

    private func getTransactions(addresses: String, from: Int = 0) -> Single<InsightResponseItem> {
        let parameters: Parameters = [
            "from": from,
            "to": from + InsightApi.paginationLimit
        ]
        let path = "/addrs/\(addresses)/txs"

        let request = networkManager.session.request(url + path, method: .get, parameters: parameters)

        return networkManager.single(request: request)
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
            var fromInt: Int?
            if let fromString: String = try? map.value("from") {
                fromInt = Int(fromString)
            } else {
                fromInt = try? map.value("from")
            }
            guard let from = fromInt else {
                throw MapError(key: "from", currentValue: "n/a", reason: "can't parse from value")
            }
            self.from = from
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
            let script: String = (try? map.value("scriptPubKey.hex")) ?? ""
            let address: [String] = (try? map.value("scriptPubKey.addresses")) ?? []
            super.init(script: script, address: address.joined())
        }

    }

}
