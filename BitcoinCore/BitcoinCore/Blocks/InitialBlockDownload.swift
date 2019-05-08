import RxSwift

public enum InitialBlockDownloadEvent {
    case onPeerSynced(peer: IPeer)
    case onPeerNotSynced(peer: IPeer)
}

public class InitialBlockDownload {
    private var disposeBag = DisposeBag()
    private var blockSyncer: IBlockSyncer?
    private let peerManager: IPeerManager
    private let syncStateListener: ISyncStateListener

    private let subject = PublishSubject<InitialBlockDownloadEvent>()
    public let observable: Observable<InitialBlockDownloadEvent>

    private var syncedStates = [String: Bool]()
    private var blockHashesSyncedStates = [String: Bool]()

    private var syncPeer: IPeer?
    private let peersQueue: DispatchQueue
    private let logger: Logger?

    public var syncedPeers = [IPeer]()

    init(blockSyncer: IBlockSyncer?, peerManager: IPeerManager, syncStateListener: ISyncStateListener,
         peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .background),
         logger: Logger? = nil) {
        self.blockSyncer = blockSyncer
        self.peerManager = peerManager
        self.syncStateListener = syncStateListener
        self.peersQueue = peersQueue
        self.logger = logger
        self.observable = subject.asObservable().observeOn(scheduler)
    }

    private func syncedState(_ peer: IPeer) -> Bool {
        return syncedStates[peer.host] ?? false
    }

    private func blockHashesSyncedState(_ peer: IPeer) -> Bool {
        return blockHashesSyncedStates[peer.host] ?? false
    }

    private func assignNextSyncPeer() {
        peersQueue.async {
            guard self.syncPeer == nil else {
                return
            }

            let nonSyncedPeers = self.peerManager.connected().filter { !self.syncedState($0) }

            if let peer = nonSyncedPeers.first(where: { $0.ready }) {
                self.logger?.debug("Setting sync peer to \(peer.logName)")
                self.syncPeer = peer
                self.blockSyncer?.downloadStarted()
                self.downloadBlockchain()
            }
        }
    }

    private func downloadBlockchain() {
        peersQueue.async {
            guard let blockSyncer = self.blockSyncer, let syncPeer = self.syncPeer, syncPeer.ready else {
                return
            }

            let blockHashes = blockSyncer.getBlockHashes()
            if blockHashes.isEmpty {
                self.syncedStates[syncPeer.host] = self.blockHashesSyncedStates[syncPeer.host]
            } else {
                syncPeer.add(task: GetMerkleBlocksTask(blockHashes: blockHashes, merkleBlockHandler: self))
            }

            if !self.blockHashesSyncedState(syncPeer) {
                let blockLocatorHashes = blockSyncer.getBlockLocatorHashes(peerLastBlockHeight: syncPeer.announcedLastBlockHeight)
                let expectedHashesMinCount = max(syncPeer.announcedLastBlockHeight - blockSyncer.localKnownBestBlockHeight, 0)

                syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes, expectedHashesMinCount: expectedHashesMinCount))
            }

            if self.syncedState(syncPeer) {
                self.syncedPeers.append(syncPeer)
                blockSyncer.downloadCompleted()
                self.syncStateListener.syncFinished()
                syncPeer.sendMempoolMessage()
                self.syncPeer = nil
                self.subject.onNext(.onPeerSynced(peer: syncPeer))
                self.assignNextSyncPeer()
            }
        }
    }

    func subscribeTo(observable: Observable<PeerGroupEvent>) {
        observable.subscribe(
                        onNext: { [weak self] in
                            switch $0 {
                            case .onStart: self?.onStart()
                            case .onStop: self?.onStop()
                            case .onPeerCreate(let peer): self?.onPeerCreate(peer: peer)
                            case .onPeerConnect(let peer): self?.onPeerConnect(peer: peer)
                            case .onPeerDisconnect(let peer, let error): self?.onPeerDisconnect(peer: peer, error: error)
                            case .onPeerReady(let peer): self?.onPeerReady(peer: peer)
                            default: ()
                            }
                        }
                )
                .disposed(by: disposeBag)
    }

}

extension InitialBlockDownload: IInitialBlockDownload {

    public func isSynced(peer: IPeer) -> Bool {
        return syncedState(peer)
    }

}

extension InitialBlockDownload: IInventoryItemsHandler {

    public func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        if syncedState(peer) && inventoryItems.first(where: { $0.type == InventoryItem.ObjectType.blockMessage.rawValue }) != nil {
            syncedStates[peer.host] = false
            blockHashesSyncedStates[peer.host] = false
            subject.onNext(.onPeerNotSynced(peer: peer))
            if let index = syncedPeers.index(where: { $0.equalTo(peer) }) {
                syncedPeers.remove(at: index)
            }
            assignNextSyncPeer()
        }
    }

}

extension InitialBlockDownload: IPeerTaskHandler {

    public func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let t as GetBlockHashesTask:
            if t.blockHashes.isEmpty {
                blockHashesSyncedStates[peer.host] = true
            } else {
                blockSyncer?.add(blockHashes: t.blockHashes)
            }
            return true
        case is GetMerkleBlocksTask:
            blockSyncer?.downloadIterationCompleted()
            return true
        default: return false
        }
    }

}

extension InitialBlockDownload {

    private func onStart() {
        syncStateListener.syncStarted()
        blockSyncer?.prepareForDownload()
    }

    private func onStop() {
        syncStateListener.syncStopped()
    }

    private func onPeerCreate(peer: IPeer) {
        peer.localBestBlockHeight = blockSyncer?.localDownloadedBestBlockHeight ?? 0
    }

    private func onPeerConnect(peer: IPeer) {
        syncedStates[peer.host] = false
        assignNextSyncPeer()
    }

    private func onPeerDisconnect(peer: IPeer, error: Error?) {
        if let index = syncedPeers.index(where: { $0.equalTo(peer) }) {
            syncedPeers.remove(at: index)
        }
        syncedStates.removeValue(forKey: peer.host)

        if peer.equalTo(syncPeer) {
            syncPeer = nil
            blockSyncer?.downloadFailed()
            assignNextSyncPeer()
        }
    }

    private func onPeerReady(peer: IPeer) {
        if peer.equalTo(syncPeer) {
            downloadBlockchain()
        }
    }

}

extension InitialBlockDownload: IMerkleBlockHandler {

    func handle(merkleBlock: MerkleBlock) throws {
        let maxBlockHeight = syncPeer?.announcedLastBlockHeight ?? 0
        try blockSyncer?.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)
    }

}
