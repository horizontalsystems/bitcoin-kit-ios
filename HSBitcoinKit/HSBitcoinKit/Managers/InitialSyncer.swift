import HSHDWalletKit
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()

    private let realmFactory: IRealmFactory
    private let hdWallet: IHDWallet
    private var stateManager: IStateManager
    private let apiManager: IApiManager
    private let addressManager: IAddressManager
    private let addressConverter: IAddressConverter
    private let factory: IFactory
    private let peerGroup: IPeerGroup
    private let network: INetwork
    private let scheduler: ImmediateSchedulerType

    init(realmFactory: IRealmFactory, hdWallet: IHDWallet, stateManager: IStateManager, apiManager: IApiManager, addressManager: IAddressManager, addressConverter: IAddressConverter, factory: IFactory, peerGroup: IPeerGroup, network: INetwork, scheduler: ImmediateSchedulerType = ConcurrentDispatchQueueScheduler(qos: .background)) {
        self.realmFactory = realmFactory
        self.hdWallet = hdWallet
        self.stateManager = stateManager
        self.apiManager = apiManager
        self.addressManager = addressManager
        self.addressConverter = addressConverter
        self.factory = factory
        self.peerGroup = peerGroup
        self.network = network
        self.scheduler = scheduler
    }

    private func handle(keys: [PublicKey], responses: [BlockResponse]) throws {
        let blocks = responses.compactMap { response -> BlockHash? in
            if let hash = Data(hex: response.hash) {
                return self.factory.blockHash(withHeaderHash: Data(hash.reversed()), height: response.height)
            }
            return nil
        }

        Logger.shared.log(self, "SAVING: \(keys.count) keys, \(blocks.count) blocks")

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

        return apiManager.getBlockHashes(address: addressConverter.convertToLegacy(keyHash: newKey.keyHash, version: network.pubKeyHash, addressType: .pubKeyHash).stringValue)
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

}

extension InitialSyncer: IInitialSyncer {

    func sync() throws {
//        if !stateManager.apiSynced {
//            let maxHeight = network.checkpointBlock.height
//
//            let externalObservable = try fetchFromApi(external: true, maxHeight: maxHeight)
//            let internalObservable = try fetchFromApi(external: false, maxHeight: maxHeight)
//
//            Observable
//                    .zip(externalObservable, internalObservable, resultSelector: { external, `internal` -> ([PublicKey], [BlockResponse]) in
//                        let (externalKeys, externalResponses) = external
//                        let (internalKeys, internalResponses) = `internal`
//
//                        let set: Set<BlockResponse> = Set(externalResponses + internalResponses)
//
//                        return (externalKeys + internalKeys, Array(set))
//                    })
//                    .subscribeOn(scheduler)
//                    .subscribe(onNext: { [weak self] keys, responses in
//                        try? self?.handle(keys: keys, responses: responses)
//                    }, onError: { error in
//                        Logger.shared.log(self, "Error: \(error)")
//                    })
//                    .disposed(by: disposeBag)
//        } else {
//            peerGroup.start()
//        }

        var keys = [PublicKey]()
        for i in 0...20 {
            keys.append(try hdWallet.publicKey(index: i, external: true))
            keys.append(try hdWallet.publicKey(index: i, external: false))
        }
        try handle(keys: keys, responses: [])
    }

}
