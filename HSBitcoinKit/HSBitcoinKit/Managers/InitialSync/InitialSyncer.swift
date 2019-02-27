import HSHDWalletKit
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()
    private var restoreDisposable: Disposable?

    private let realmFactory: IRealmFactory
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

    init(realmFactory: IRealmFactory, listener: ISyncStateListener, hdWallet: IHDWallet, stateManager: IStateManager, blockDiscovery: IBlockDiscovery, addressManager: IAddressManager, factory: IFactory, peerGroup: IPeerGroup, reachabilityManager: IReachabilityManager, async: Bool = true, logger: Logger? = nil) {
        self.realmFactory = realmFactory
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

        var observable = Observable.concat(externalObservable, internalObservable).toArray().map { array -> ([PublicKey], [BlockResponse]) in
            let (externalKeys, externalResponses) = array[0]
            let (internalKeys, internalResponses) = array[1]

            let set: Set<BlockResponse> = Set(externalResponses + internalResponses)

            return (externalKeys + internalKeys, Array(set))
        }

        if async {
            observable = observable.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
        }

        observable.subscribe(onNext: { [weak self] keys, responses in
                    self?.handle(forAccount: account, keys: keys, responses: responses)
                }, onError: { [weak self] error in
                    self?.handle(error: error)
                })
                .disposed(by: disposeBag)
    }

    private func handle(forAccount account: Int, keys: [PublicKey], responses: [BlockResponse]) {
        let blocks = responses.compactMap { response -> BlockHash? in
            if let hash = Data(hex: response.hash) {
                return self.factory.blockHash(withHeaderHash: Data(hash.reversed()), height: response.height)
            }
            return nil
        }

        do {
            logger?.debug("Account \(account) has \(keys.count) keys and \(blocks.count) blocks")
            try addressManager.addKeys(keys: keys)

            // If gap shift is found
            if blocks.isEmpty {
                stateManager.restored = true

                stop()
                try sync()

                return
            }

            let realm = realmFactory.realm
            try realm.write {
                realm.add(blocks, update: true)
            }

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
        if !stateManager.restored {
            if restoreDisposable == nil {
                restoreDisposable = reachabilityManager.reachabilitySignal.subscribe(onNext: { [weak self] in
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
        restoreDisposable?.dispose()
        restoreDisposable = nil

        peerGroup.stop()
    }

}

struct BlockResponse: Hashable {
    let hash: String
    let height: Int

    var hashValue: Int {
        return hash.hashValue ^ height.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(hash)
        hasher.combine(height)
    }

    static func ==(lhs: BlockResponse, rhs: BlockResponse) -> Bool {
        return lhs.height == rhs.height && lhs.hash == rhs.hash
    }

}
