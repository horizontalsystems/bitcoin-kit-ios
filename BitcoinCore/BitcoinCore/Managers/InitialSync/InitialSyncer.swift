import HSHDWalletKit
import RxSwift

class InitialSyncer {
    weak var delegate: IInitialSyncerDelegate?

    private var disposeBag = DisposeBag()

    private let storage: IStorage
    private let listener: ISyncStateListener
    private var stateManager: IStateManager
    private let blockDiscovery: IBlockDiscovery
    private let publicKeyManager: IPublicKeyManager

    private let logger: Logger?
    private let async: Bool

    private var restoring = false

    init(storage: IStorage, listener: ISyncStateListener, stateManager: IStateManager, blockDiscovery: IBlockDiscovery, publicKeyManager: IPublicKeyManager, async: Bool = true, logger: Logger? = nil) {
        self.storage = storage
        self.listener = listener
        self.stateManager = stateManager
        self.blockDiscovery = blockDiscovery
        self.publicKeyManager = publicKeyManager

        self.logger = logger
        self.async = async
    }

    private func sync(forAccount account: Int) {
        let externalObservable = blockDiscovery.discoverBlockHashes(account: account, external: true)
        let internalObservable = blockDiscovery.discoverBlockHashes(account: account, external: false)

        var observable = Observable
                .concat(externalObservable, internalObservable)
                .toArray()
                .map { array -> ([PublicKey], [BlockHash]) in
                    let (externalKeys, externalBlockHashes) = array[0]
                    let (internalKeys, internalBlockHashes) = array[1]
                    let sortedUniqueBlockHashes = Array<BlockHash>(externalBlockHashes + internalBlockHashes).unique.sorted { a, b in a.height < b.height }

                    return (externalKeys + internalKeys, sortedUniqueBlockHashes)
                }

        if async {
            observable = observable.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }
        
        observable.subscribe(onSuccess: { [weak self] keys, responses in
                    self?.handle(forAccount: account, keys: keys, blockHashes: responses)
                }, onError: { [weak self] error in
                    self?.handle(error: error)
                })
                .disposed(by: disposeBag)
    }

    private func handle(forAccount account: Int, keys: [PublicKey], blockHashes: [BlockHash]) {
        do {
            logger?.debug("Account \(account) has \(keys.count) keys and \(blockHashes.count) blocks")
            try publicKeyManager.addKeys(keys: keys)

            // If gap shift is found
            if blockHashes.isEmpty {
                stateManager.restored = true
                delegate?.syncingFinished()
            } else {
                storage.add(blockHashes: blockHashes)
                sync(forAccount: account + 1)
            }

        } catch {
            handle(error: error)
        }
    }

    private func handle(error: Error) {
        stop()
        logger?.error(error)
        listener.syncStopped()
    }

}

extension InitialSyncer: IInitialSyncer {

    func sync() {
        guard !stateManager.restored else {
            delegate?.syncingFinished()
            return
        }

        guard !restoring else {
            return
        }
        restoring = true

        listener.syncStarted()
        sync(forAccount: 0)
    }

    func stop() {
        restoring = false
        // Deinit old DisposeGag
        disposeBag = DisposeBag()
    }

}
