import HSHDWalletKit
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()
    private var reachabilityDisposable: Disposable?

    private let storage: IStorage
    private let listener: ISyncStateListener
    private let hdWallet: IHDWallet
    private var stateManager: IStateManager
    private let blockDiscovery: IBlockDiscovery
    private let addressManager: IAddressManager
    private let factory: IFactory
    private let peerGroup: IPeerGroup
    private let reachabilityManager: IReachabilityManager

    private let logger: Logger?
    private let async: Bool

    private var started = false
    private var restoring = false

    init(storage: IStorage, listener: ISyncStateListener, hdWallet: IHDWallet, stateManager: IStateManager, blockDiscovery: IBlockDiscovery, addressManager: IAddressManager, factory: IFactory, peerGroup: IPeerGroup, reachabilityManager: IReachabilityManager, async: Bool = true, logger: Logger? = nil) {
        self.storage = storage
        self.listener = listener
        self.hdWallet = hdWallet
        self.stateManager = stateManager
        self.blockDiscovery = blockDiscovery
        self.addressManager = addressManager
        self.factory = factory
        self.peerGroup = peerGroup
        self.reachabilityManager = reachabilityManager

        self.logger = logger

        self.async = async
    }

    private func onChangeConnection() {
        if reachabilityManager.isReachable {
            try? sync()
        }
    }

    private func sync(forAccount account: Int) {

        let externalObservable = blockDiscovery.discoverBlockHashes(account: account, external: true)
        let internalObservable = blockDiscovery.discoverBlockHashes(account: account, external: false)

        var observable = Observable
                .concat(externalObservable, internalObservable)
                .toArray()
                .map { array -> ([PublicKey], [BlockHash]) in
                    let (externalKeys, externalResponses) = array[0]
                    let (internalKeys, internalResponses) = array[1]

                    let set: Set<BlockHash> = Set(externalResponses + internalResponses)

                    return (externalKeys + internalKeys, Array(set))
                }

        if async {
            observable = observable.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }

        observable.subscribe(onNext: { [weak self] keys, responses in
                    self?.handle(forAccount: account, keys: keys, blockHashes: responses)
                }, onError: { [weak self] error in
                    self?.handle(error: error)
                })
                .disposed(by: disposeBag)
    }

    private func handle(forAccount account: Int, keys: [PublicKey], blockHashes: [BlockHash]) {
        do {
            logger?.debug("Account \(account) has \(keys.count) keys and \(blockHashes.count) blocks")
            try addressManager.addKeys(keys: keys)

            // If gap shift is found
            if blockHashes.isEmpty {
                stateManager.restored = true

                restoring = false
                // Unsubscribe to ReachabilityManager
                reachabilityDisposable?.dispose()
                reachabilityDisposable = nil
                try sync()

                return
            }

            storage.add(blockHashes: blockHashes)
            sync(forAccount: account + 1)
        } catch {
            handle(error: error)
        }
    }

    private func handle(error: Error) {
        restoring = false
        logger?.error(error)
        listener.syncStopped()
    }

}

extension InitialSyncer: IInitialSyncer {

    func sync() throws {
        try addressManager.fillGap()

        if !stateManager.restored {
            if reachabilityDisposable == nil {
                reachabilityDisposable = reachabilityManager.reachabilitySignal.subscribe(onNext: { [weak self] in
                    self?.onChangeConnection()
                })
            }
            guard !restoring else {
                return
            }

            restoring = true
            listener.syncStarted()

            sync(forAccount: 0)
        } else {
            peerGroup.start()
        }
    }

    func stop() {
        restoring = false
        // Unsubscribe to ReachabilityManager
        reachabilityDisposable?.dispose()
        reachabilityDisposable = nil

        peerGroup.stop()
    }

}
