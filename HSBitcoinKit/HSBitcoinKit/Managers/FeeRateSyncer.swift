import Foundation
import RxSwift

class FeeRateSyncer {
    private let disposeBag = DisposeBag()

    private let api: IFeeRateApi
    private let storage: IStorage

    init(api: IFeeRateApi, storage: IStorage) {
        self.api = api
        self.storage = storage
    }

}

extension FeeRateSyncer: IFeeRateSyncer {

    func sync() {
        api.getFeeRate()
                .subscribe(onNext: { [weak self] feeRate in
                    self?.storage.save(feeRate: feeRate)
                }, onError: { _ in
                    //do nothing
                })
                .disposed(by: disposeBag)

    }

}
