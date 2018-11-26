import HSHDWalletKit
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()

    private let realmFactory: IRealmFactory
    private let hdWallet: IHDWallet
    private var stateManager: IStateManager
    private let api: IInitialSyncApi
    private let addressManager: IAddressManager
    private let addressSelector: IAddressSelector
    private let factory: IFactory
    private let peerGroup: IPeerGroup
    private let network: INetwork

    private let async: Bool

    init(realmFactory: IRealmFactory, hdWallet: IHDWallet, stateManager: IStateManager, api: IInitialSyncApi, addressManager: IAddressManager, addressSelector: IAddressSelector, factory: IFactory, peerGroup: IPeerGroup, network: INetwork, async: Bool = true) {
        self.realmFactory = realmFactory
        self.hdWallet = hdWallet
        self.stateManager = stateManager
        self.api = api
        self.addressManager = addressManager
        self.addressSelector = addressSelector
        self.factory = factory
        self.peerGroup = peerGroup
        self.network = network

        self.async = async
    }

    private func handle(keys: [PublicKey], responses: [BlockResponse]) throws {
        let blocks = responses.compactMap { response -> BlockHash? in
            if let hash = Data(hex: response.hash) {
                return self.factory.blockHash(withHeaderHash: Data(hash.reversed()), height: response.height)
            }
            return nil
        }

        btcKitLog.debug("SAVING: \(keys.count) keys, \(blocks.count) blocks")

        let realm = realmFactory.realm
        try realm.write {
            realm.add(blocks, update: true)
        }

        try addressManager.addKeys(keys: keys)

        stateManager.apiSynced = true
        peerGroup.start()
    }

    private func fetchFromApi(external: Bool, maxHeight: Int, lastUsedKeyIndex: Int = -1, keys: [PublicKey] = [], responses: [BlockResponse] = []) throws -> Observable<([PublicKey], [BlockResponse])> {
        let count = keys.count
        let gapLimit = hdWallet.gapLimit

        let newKey = try hdWallet.publicKey(index: count, external: external)

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
                        return try self.fetchFromApi(external: external, maxHeight: maxHeight, lastUsedKeyIndex: lastUsedKeyIndex, keys: keys, responses: responses + validResponses)
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
            stateManager.apiSynced = true
        }

        if !stateManager.apiSynced {
            let maxHeight = network.checkpointBlock.height

            let externalObservable = try fetchFromApi(external: true, maxHeight: maxHeight)
            let internalObservable = try fetchFromApi(external: false, maxHeight: maxHeight)

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
                        try? self?.handle(keys: keys, responses: responses)
                    }, onError: { [weak self] error in
                        // TODO: make handle error
                        btcKitLog.error(error)
//                        self?.peerGroup.start()
                    })
                    .disposed(by: disposeBag)
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
