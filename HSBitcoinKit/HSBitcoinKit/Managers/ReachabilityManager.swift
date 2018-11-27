import Foundation
import Alamofire
import RxSwift

class ReachabilityManager: IReachabilityManager {

    var subject = PublishSubject<Bool>()
    private let manager: NetworkReachabilityManager?

    init(configProvider: IApiConfigProvider? = nil) {
        if let configProvider = configProvider {
            manager = NetworkReachabilityManager(host: configProvider.reachabilityHost)
        } else {
            manager = NetworkReachabilityManager()
        }

        manager?.listener = { [weak self] status in
            switch status {
            case .reachable:
                self?.subject.onNext(true)
            default:
                self?.subject.onNext(false)
            }
        }

        manager?.startListening()
    }

    func reachable() -> Bool {
        return manager?.isReachable ?? false
    }

}
