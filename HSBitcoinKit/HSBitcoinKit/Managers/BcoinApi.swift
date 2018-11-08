import Foundation
import RxSwift
import ObjectMapper

class BcoinApi {
    private let apiManager: ApiManager

    init(network: INetwork) {
        let url: String

        switch network {
        case is BitcoinMainNet: url = "https://bcoin.grouvi.im"
        case is BitcoinTestNet: url = "http://bcoin.grouvi.org"
        case is BitcoinCashMainNet: url = "https://bcash.grouvi.im"
        case is BitcoinCashTestNet: url = "http://bcash.grouvi.org"
        default: url = "http://bcoin.grouvi.org"
        }

        apiManager = ApiManager(apiUrl: url)
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
