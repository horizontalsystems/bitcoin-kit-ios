import Foundation
import RxSwift

class FeeRateSyncer {
    private let disposeBag = DisposeBag()

    weak var delegate: IFeeRateSyncerDelegate?

    private let networkManager: IFeeRateApi
    private let async: Bool

    init(networkManager: IFeeRateApi, async: Bool = true) {
        self.networkManager = networkManager
        self.async = async
    }

}

extension FeeRateSyncer: IFeeRateSyncer {

    func sync() {
        var observable = networkManager.getFeeRate()

        if async {
            observable = observable.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }
        observable
                .subscribe(onNext: { [weak self] feeRate in
                    self?.delegate?.didSync(feeRate: feeRate)
                }, onError: { _ in
                    //do nothing
                })
                .disposed(by: disposeBag)

    }

}
