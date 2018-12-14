import HSHDWalletKit
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()

    private let realmFactory: IRealmFactory
    private let listener: ISyncStateListener
    private let hdWallet: IHDWallet
    private var stateManager: IStateManager
    private let api: IInitialSyncApi
    private let addressManager: IAddressManager
    private let addressSelector: IAddressSelector
    private let factory: IFactory
    private let peerGroup: IPeerGroup
    private let network: INetwork

    private let logger: Logger?
    private let async: Bool

    private var syncing = false

    init(realmFactory: IRealmFactory, listener: ISyncStateListener, hdWallet: IHDWallet, stateManager: IStateManager, api: IInitialSyncApi, addressManager: IAddressManager, addressSelector: IAddressSelector, factory: IFactory, peerGroup: IPeerGroup, network: INetwork, async: Bool = true, logger: Logger? = nil) {
        self.realmFactory = realmFactory
        self.listener = listener
        self.hdWallet = hdWallet
        self.stateManager = stateManager
        self.api = api
        self.addressManager = addressManager
        self.addressSelector = addressSelector
        self.factory = factory
        self.peerGroup = peerGroup
        self.network = network

        self.logger = logger

        self.async = async
    }

    private func sync(forAccount account: Int) {
        let maxHeight = network.checkpointBlock.height

        let externalObservable = fetchFromApi(forAccount: account, external: true, maxHeight: maxHeight)
        let internalObservable = fetchFromApi(forAccount: account, external: false, maxHeight: maxHeight)

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
            if keys.count <= hdWallet.gapLimit * 2 {
                syncing = false
                stateManager.restored = true
                peerGroup.start()
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
        syncing = false
        logger?.error(error)
        listener.syncStopped()
    }

    private func fetchFromApi(forAccount account: Int, external: Bool, maxHeight: Int, lastUsedKeyIndex: Int = -1, keys: [PublicKey] = [], responses: [BlockResponse] = []) -> Observable<([PublicKey], [BlockResponse])> {
        let count = keys.count
        let gapLimit = hdWallet.gapLimit
        let newKey: PublicKey!

        do {
            newKey = try hdWallet.publicKey(account: account, index: count, external: external)
        } catch {
            return Observable.error(error)
        }

        return getBlockHashes(publicKey: newKey)
                .flatMap { [unowned self] blockResponses -> Observable<([PublicKey], [BlockResponse])> in
                    var lastUsedKeyIndex = lastUsedKeyIndex

                    if !blockResponses.isEmpty {
                        lastUsedKeyIndex = keys.count
                    }

                    let keys = keys + [newKey]

                    if lastUsedKeyIndex < keys.count - gapLimit {
                        return Observable.just((keys, responses))
                    } else {
                        let validResponses = blockResponses.filter { $0.height <= maxHeight }
                        return self.fetchFromApi(forAccount: account, external: external, maxHeight: maxHeight, lastUsedKeyIndex: lastUsedKeyIndex, keys: keys, responses: responses + validResponses)
                    }
                }
    }

    private func getBlockHashes(publicKey: PublicKey) -> Observable<Set<BlockResponse>> {
        let observables = addressSelector.getAddressVariants(publicKey: publicKey).map { address in
            api.getBlockHashes(address: address)
        }

        return Observable.concat(observables).toArray().map { blockResponses in
            return Set(blockResponses.flatMap { Array($0) })
        }
    }

}

extension InitialSyncer: IInitialSyncer {

    func sync() throws {
        try addressManager.fillGap()

        if !network.syncableFromApi {
            stateManager.restored = true
        }

        if !stateManager.restored {
            guard !syncing else {
                return
            }

            syncing = true
            listener.syncStarted()

            sync(forAccount: 0)
        } else {
            peerGroup.start()
        }
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
