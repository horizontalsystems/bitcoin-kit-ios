import Foundation
import RxSwift
import RealmSwift

class InitialSyncer {
    private let disposeBag = DisposeBag()

    private let realmFactory: RealmFactory
    private let hdWallet: HDWallet
    private let stateManager: StateManager
    private let apiManager: ApiManager
    private let factory: Factory
    private let peerGroup: PeerGroup
    private let network: NetworkProtocol
    private let scheduler: ImmediateSchedulerType

    init(realmFactory: RealmFactory, hdWallet: HDWallet, stateManager: StateManager, apiManager: ApiManager, factory: Factory, peerGroup: PeerGroup, network: NetworkProtocol, scheduler: ImmediateSchedulerType = ConcurrentDispatchQueueScheduler(qos: .background)) {
        self.realmFactory = realmFactory
        self.hdWallet = hdWallet
        self.stateManager = stateManager
        self.apiManager = apiManager
        self.factory = factory
        self.peerGroup = peerGroup
        self.network = network
        self.scheduler = scheduler
    }

    func sync() throws {
        if !stateManager.apiSynced {
            let maxHeight = network.checkpointBlock.height

            let externalObservable = try fetchFromApi(external: true, maxHeight: maxHeight)
            let internalObservable = try fetchFromApi(external: false, maxHeight: maxHeight)

            Observable
                    .zip(externalObservable, internalObservable, resultSelector: { external, `internal` -> ([PublicKey], [Block]) in
                        let (externalKeys, externalBlocks) = external
                        let (internalKeys, internalBlocks) = `internal`

                        return (externalKeys + internalKeys, externalBlocks + internalBlocks)
                    })
                    .subscribeOn(scheduler)
                    .subscribe(onNext: { [weak self] keys, blocks in
                        try? self?.handle(keys: keys, blocks: blocks)
                    }, onError: { error in
                        Logger.shared.log(self, "Error: \(error)")
                    })
                    .disposed(by: disposeBag)
        } else {
            peerGroup.start()
        }
    }

    private func handle(keys: [PublicKey], blocks: [Block]) throws {
        Logger.shared.log(self, "SAVING: \(keys.count) keys, \(blocks.count) blocks")

        let realm = realmFactory.realm

        try realm.write {
            realm.add(keys, update: true)
            realm.add(blocks, update: true)
        }

        stateManager.apiSynced = true
        peerGroup.start()
    }

    private func fetchFromApi(external: Bool, maxHeight: Int, lastUsedKeyIndex: Int = -1, keys: [PublicKey] = [], blocks: [Block] = []) throws -> Observable<([PublicKey], [Block])> {
        let count = keys.count
        let gapLimit = hdWallet.gapLimit

        let newKey = try hdWallet.publicKey(index: count, external: external)

        return apiManager.getBlockHashes(address: newKey.address)
                .flatMap { [unowned self] blockResponses -> Observable<([PublicKey], [Block])> in
                    var lastUsedKeyIndex = lastUsedKeyIndex

                    if !blockResponses.isEmpty {
                        lastUsedKeyIndex = keys.count
                    }

                    let keys = keys + [newKey]

                    if lastUsedKeyIndex < keys.count - gapLimit {
                        return Observable.just((keys, blocks))
                    } else {
                        let validResponses = blockResponses.filter { $0.height < maxHeight }

                        let validBlocks = validResponses.compactMap { response -> Block? in
                            if let hash = Data(hex: response.hash) {
                                return self.factory.block(withHeaderHash: Data(hash.reversed()), height: response.height)
                            }
                            return nil
                        }

                        let blocks = blocks + validBlocks
                        return try self.fetchFromApi(external: external, maxHeight: maxHeight, lastUsedKeyIndex: lastUsedKeyIndex, keys: keys, blocks: blocks)
                    }
                }
    }

}
