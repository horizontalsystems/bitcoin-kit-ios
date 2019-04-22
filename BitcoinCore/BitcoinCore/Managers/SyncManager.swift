import RxSwift

class SyncManager {
    private let feeRateSyncPeriod: TimeInterval = 3 * 60

    private let disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let feeRateSyncer: IFeeRateSyncer
    private let initialSyncer: IInitialSyncer
    private let peerGroup: IPeerGroup

    init(reachabilityManager: IReachabilityManager, feeRateSyncer: IFeeRateSyncer, initialSyncer: IInitialSyncer, peerGroup: IPeerGroup) {
        self.reachabilityManager = reachabilityManager
        self.feeRateSyncer = feeRateSyncer
        self.initialSyncer = initialSyncer
        self.peerGroup = peerGroup
    }

    private func syncFeeRate() {
        if reachabilityManager.isReachable {
            feeRateSyncer.sync()
            initialSyncer.sync()
        }
    }

}

extension SyncManager: ISyncManager {

    func start() {
        reachabilityManager.reachabilitySignal
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] in
                    self?.syncFeeRate()
                })
                .disposed(by: disposeBag)

        Observable<Int>.timer(0, period: feeRateSyncPeriod, scheduler: ConcurrentDispatchQueueScheduler(qos: .background))
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] _ in
                    self?.syncFeeRate()
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
