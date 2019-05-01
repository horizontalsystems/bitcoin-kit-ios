import RxSwift

class SyncManager {
    private var disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup

    init(reachabilityManager: IReachabilityManager, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup) {
        self.reachabilityManager = reachabilityManager
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
    }

    private func startSync() {
        if reachabilityManager.isReachable {
            initialSyncer.sync()
        }
    }

    private func stopSync() {
        initialSyncer.stop()
        peerGroup.stop()
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

        initialSyncer.sync()
    }

    func stop() {
        disposeBag = DisposeBag()
        stopSync()
    }

}

extension SyncManager: IInitialSyncerDelegate {

    func syncingFinished() {
        initialSyncer.stop()
        peerGroup.start()
    }

}
