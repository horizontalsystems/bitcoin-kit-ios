import HdWalletKit
import RxSwift
import HsToolKit

class InitialSyncer {
    weak var delegate: IInitialSyncerDelegate?

    private var disposeBag = DisposeBag()

    private let storage: IStorage
    private let blockDiscovery: IBlockDiscovery
    private let publicKeyManager: IPublicKeyManager

    private let logger: Logger?
    private let async: Bool

    init(storage: IStorage, blockDiscovery: IBlockDiscovery, publicKeyManager: IPublicKeyManager,
         async: Bool = true, logger: Logger? = nil) {
        self.storage = storage
        self.blockDiscovery = blockDiscovery
        self.publicKeyManager = publicKeyManager

        self.logger = logger
        self.async = async
    }

    private func sync(forAccount account: Int) {
        var single = blockDiscovery.discoverBlockHashes(account: account)
                .map { array -> ([PublicKey], [BlockHash]) in
                    let (keys, blockHashes) = array
                    let sortedUniqueBlockHashes = blockHashes.unique.sorted { a, b in a.height < b.height }

                    return (keys, sortedUniqueBlockHashes)
                }

        if async {
            single = single.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }

        single.subscribe(onSuccess: { [weak self] keys, responses in
                    self?.handle(forAccount: account, keys: keys, blockHashes: responses)
                }, onError: { [weak self] error in
                    self?.handle(error: error)
                })
                .disposed(by: disposeBag)
    }

    private func handle(forAccount account: Int, keys: [PublicKey], blockHashes: [BlockHash]) {
        logger?.debug("Account \(account) has \(keys.count) keys and \(blockHashes.count) blocks")
        publicKeyManager.addKeys(keys: keys)

        // If gap shift is found
        if blockHashes.isEmpty {
            handleSuccess()
        } else {
            storage.add(blockHashes: blockHashes)
            sync(forAccount: account + 1)
        }
    }

    private func handleSuccess() {
        delegate?.onSyncSuccess()
    }

    private func handle(error: Error) {
        logger?.error(error, context: ["apiSync"], save: true)
        delegate?.onSyncFailed(error: error)
    }

}

extension InitialSyncer: IInitialSyncer {

    func sync() {
        sync(forAccount: 0)
    }

    func terminate() {
        disposeBag = DisposeBag()
    }

}
