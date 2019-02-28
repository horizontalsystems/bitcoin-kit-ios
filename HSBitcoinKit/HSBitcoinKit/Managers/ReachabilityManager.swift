import RxSwift
import Alamofire

class ReachabilityManager {
    private let manager: NetworkReachabilityManager?

    private(set) var isReachable: Bool
    let reachabilitySignal = Signal()

    init(configProvider: IApiConfigProvider? = nil) {
        if let configProvider = configProvider {
            manager = NetworkReachabilityManager(host: configProvider.reachabilityHost)
        } else {
            manager = NetworkReachabilityManager()
        }

        isReachable = manager?.isReachable ?? false

        manager?.listener = { [weak self] _ in
            self?.onUpdateStatus()
        }

        manager?.startListening()
    }

    private func onUpdateStatus() {
        let newReachable = manager?.isReachable ?? false

        if isReachable != newReachable {
            isReachable = newReachable
            reachabilitySignal.notify()
        }
    }

}

extension ReachabilityManager: IReachabilityManager {
}
