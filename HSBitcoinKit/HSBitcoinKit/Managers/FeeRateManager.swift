import Foundation
import RxSwift

class FeeRateManager {
    private let disposeBag = DisposeBag()

    let subject = PublishSubject<Void>()

    private let storage: IFeeRateStorage
    private let syncer: IFeeRateSyncer
    private var timer: IPeriodicTimer

    init(storage: IFeeRateStorage, syncer: IFeeRateSyncer, reachabilityManager: IReachabilityManager, timer: IPeriodicTimer) {
        self.storage = storage
        self.syncer = syncer
        self.timer = timer

        self.timer.delegate = self

        reachabilityManager.subject
                .subscribe(onNext: { [weak self] connected in
                    if connected {
                        self?.updateFeeRate()
                    }
                })
                .disposed(by: disposeBag)
    }

    private func updateFeeRate() {
        syncer.sync()
    }

}

extension FeeRateManager: IFeeRateManager {
    var feeRate: FeeRate {
        return storage.feeRate ?? FeeRate.defaultFeeRate
    }

    var lowValue: Int {
        return valueInSatoshi(value: feeRate.lowPriority)
    }
    var mediumValue: Int {
        return valueInSatoshi(value: feeRate.mediumPriority)
    }
    var highValue: Int {
        return valueInSatoshi(value: feeRate.highPriority)
    }

    private func valueInSatoshi(value: Double) -> Int {
        return Int(value * 100_000_000 / 1024)
    }

}

extension FeeRateManager: IPeriodicTimerDelegate {

    func onFire() {
        updateFeeRate()
    }

}

extension FeeRateManager: IFeeRateSyncerDelegate {

    func didSync(feeRate: FeeRate) {
        storage.save(feeRate: feeRate)
        subject.onNext(())
    }

}
