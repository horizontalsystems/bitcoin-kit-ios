import Foundation
import RxSwift

class FeeRateManager {
    private let disposeBag = DisposeBag()

    let subject = PublishSubject<Void>()

    private let storage: IFeeRateStorage
    private var syncer: IFeeRateSyncer
    private let reachabilityManager: IReachabilityManager

    init(storage: IFeeRateStorage, syncer: IFeeRateSyncer, reachabilityManager: IReachabilityManager, async: Bool = true) {
        self.storage = storage
        self.syncer = syncer
        self.reachabilityManager = reachabilityManager

        self.syncer.delegate = self

//        Observable<Int>.timer(0, period: 3 * 60, scheduler: ConcurrentDispatchQueueScheduler(qos: .background)).observeOn(ConcurrentDispatchQueueScheduler(qos: .background)).subscribe(onNext: { [weak self] _ in
//            self?.updateFeeRate()
//        }).disposed(by: disposeBag)
//
//        var observable = reachabilityManager.reachabilitySignal.asObservable()
//
//        if async {
//            observable = observable.observeOn(ConcurrentDispatchQueueScheduler(qos: .background))
//        }
//        observable
//                .subscribe(onNext: { [weak self] in
//                    self?.updateFeeRate()
//                })
//                .disposed(by: disposeBag)
    }

    private func updateFeeRate() {
        if reachabilityManager.isReachable {
            syncer.sync()
        }
    }

}

extension FeeRateManager: IFeeRateManager {
    var feeRate: FeeRate {
        return storage.feeRate ?? FeeRate.defaultFeeRate
    }

    var lowValue: Int {
        return feeRate.low
    }
    var mediumValue: Int {
        return feeRate.medium
    }
    var highValue: Int {
        return feeRate.high
    }

}

extension FeeRateManager: IFeeRateSyncerDelegate {

    func didSync(feeRate: FeeRate) {
        storage.save(feeRate: feeRate)
        subject.onNext(())
    }

}
