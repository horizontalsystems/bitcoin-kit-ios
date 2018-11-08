import Foundation
import Alamofire
import RxSwift

class ReachabilityManager: IReachabilityManager {

    var subject = PublishSubject<NetworkReachabilityManager.NetworkReachabilityStatus>()
    private let net: NetworkReachabilityManager?

    init() {
        net = NetworkReachabilityManager()

        net?.listener = { status in
            self.subject.onNext(status)
        }

        net?.startListening()
    }

    func reachable() -> Bool {
        return net?.isReachable ?? false
    }

}
