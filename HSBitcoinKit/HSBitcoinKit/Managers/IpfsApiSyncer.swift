import Foundation
import RxSwift

class IpfsApiManager: IApiSyncer {
    private let apiManager: IApiManager

    init(apiManager: IApiManager) {
        self.apiManager = apiManager
    }

    func getBlockHashes(publicKey: PublicKey) -> Observable<Set<BlockResponse>> {
//        let addressPath = [
//            String(address.prefix(3)),
//            String(address[address.index(address.startIndex, offsetBy: 3)..<address.index(address.startIndex, offsetBy: 6)]),
//            String(address[address.index(address.startIndex, offsetBy: 6)...])
//        ].joined(separator: "/")
//
//        let result: Observable<AddressResponse> = apiManager.observable(forRequest: apiManager.request(withMethod: .get, path: "/btc-regtest/address/\(publicKey.keyHashHex)/index.json", parameters: nil))
//
//        return result
//                .map { $0.blocks }
//                .catchError { error -> Observable<Set<BlockResponse>> in
//                    if let error = error as? ApiError, case let .serverError(status, _) = error, status == 404 {
//                        return Observable.just(Set())
//                    }
//                    return Observable.error(error)
//                }
        fatalError( )
    }

}
