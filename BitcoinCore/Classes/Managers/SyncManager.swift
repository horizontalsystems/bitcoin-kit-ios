import RxSwift

class SyncManager {
    private var disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup
    private let queue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.sync-manager", qos: .background)

    init(reachabilityManager: IReachabilityManager, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup) {
        self.reachabilityManager = reachabilityManager
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
    }

    private func startSync() {
        guard reachabilityManager.isReachable else {
            return
        }

        queue.async { [weak self] in
            self?.initialSyncer.sync()
        }
    }

    private func stopSync() {
        queue.async { [weak self] in
            self?.initialSyncer.stop()
            self?.peerGroup.stop()
        }
    }

    private func onReachabilityChanged() {
        if reachabilityManager.isReachable {
            startSync()
        } else {
            stopSync()
        }
    }

}

extension SyncManager: ISyncManager {

    func start() {
        reachabilityManager.reachabilitySignal
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] in
                    self?.onReachabilityChanged()
                })
                .disposed(by: disposeBag)

        startSync()
    }

    func stop() {
        disposeBag = DisposeBag()
        stopSync()
    }

}

extension SyncManager: IInitialSyncerDelegate {

    func syncingFinished() {
        queue.async { [weak self] in
            self?.initialSyncer.stop()
            self?.peerGroup.start()
        }
    }

}
