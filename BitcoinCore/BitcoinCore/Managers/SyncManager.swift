import RxSwift

class SyncManager {
    private let syncPeriod: TimeInterval = 3 * 60

    private let disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup

    init(reachabilityManager: IReachabilityManager, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup) {
        self.reachabilityManager = reachabilityManager
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
    }

    private func sync() {
        if reachabilityManager.isReachable {
            initialSyncer.sync()
        }
    }

}

extension SyncManager: ISyncManager {

    func start() {
        reachabilityManager.reachabilitySignal
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] in
                    self?.sync()
                })
                .disposed(by: disposeBag)

        Observable<Int>.timer(0, period: syncPeriod, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] _ in
                    self?.sync()
                }).disposed(by: disposeBag)

        initialSyncer.sync()
    }

    func stop() {
        initialSyncer.stop()
        peerGroup.stop()
    }

}

extension SyncManager: IInitialSyncerDelegate {

    func syncingFinished() {
        initialSyncer.stop()
        peerGroup.start()
    }

}
