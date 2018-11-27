import Foundation
import RxSwift

class FeeRateSyncer {
    private let disposeBag = DisposeBag()

    weak var delegate: IFeeRateSyncerDelegate?

    private let networkManager: IFeeRateApi
    private let timer: IPeriodicTimer
    private let async: Bool

    init(networkManager: IFeeRateApi, timer: IPeriodicTimer, async: Bool = true) {
        self.networkManager = networkManager
        self.timer = timer
        self.async = async
    }

}

extension FeeRateSyncer: IFeeRateSyncer {

    func sync() {
        var observable = networkManager.getFeeRate()

        if async {
            observable = observable.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background)).observeOn(MainScheduler.instance)
        }

        observable
                .subscribe(onNext: { [weak self] feeRate in
                    self?.timer.schedule()
                    self?.delegate?.didSync(feeRate: feeRate)
                }, onError: { _ in
                    //do nothing
                })
                .disposed(by: disposeBag)

    }

}
