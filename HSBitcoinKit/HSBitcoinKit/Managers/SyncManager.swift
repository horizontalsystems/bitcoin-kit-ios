import RxSwift

class SyncManager {
    private let feeRateSyncPeriod: TimeInterval = 3 * 60

    private let disposeBag = DisposeBag()

    private let reachabilityManager: IReachabilityManager
    private let feeRateSyncer: IFeeRateSyncer

    init(reachabilityManager: IReachabilityManager, feeRateSyncer: IFeeRateSyncer) {
        self.reachabilityManager = reachabilityManager
        self.feeRateSyncer = feeRateSyncer
    }

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
    }

    private func syncFeeRate() {
        if reachabilityManager.isReachable {
            feeRateSyncer.sync()
        }
    }

}
