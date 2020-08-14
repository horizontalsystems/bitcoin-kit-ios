import RxSwift
import HsToolKit

public enum InitialBlockDownloadEvent {
    case onAllPeersSynced
    case onPeerSynced(peer: IPeer)
    case onPeerNotSynced(peer: IPeer)
}

public class InitialBlockDownload {
    public weak var listener: IBlockSyncListener?
    private static let peerSwitchMinimumRatio = 1.5

    private var disposeBag = DisposeBag()
    private var blockSyncer: IBlockSyncer
    private let peerManager: IPeerManager
    private let merkleBlockValidator: IMerkleBlockValidator

    private var minMerkleBlocksCount: Double = 0
    private var minTransactionsCount: Double = 0
    private var minTransactionsSize: Double = 0
    private var slowPeersDisconnected = 0

    private let subject = PublishSubject<InitialBlockDownloadEvent>()
    public let observable: Observable<InitialBlockDownloadEvent>

    private var syncedStates = [String: Bool]()
    private var blockHashesSyncedStates = [String: Bool]()

    private var selectNewPeer = false
    private let peersQueue: DispatchQueue
    private let logger: Logger?

    public var syncedPeers = [IPeer]()
    public var syncPeer: IPeer?

    init(blockSyncer: IBlockSyncer, peerManager: IPeerManager, merkleBlockValidator: IMerkleBlockValidator,
         peersQueue: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.bitcoin-core.initial-block-download", qos: .userInitiated),
         scheduler: SchedulerType = SerialDispatchQueueScheduler(qos: .background),
         logger: Logger? = nil) {
        self.blockSyncer = blockSyncer
        self.peerManager = peerManager
        self.merkleBlockValidator = merkleBlockValidator
        self.peersQueue = peersQueue
        self.logger = logger
        self.observable = subject.asObservable().observeOn(scheduler)
        resetRequiredDownloadSpeed()
    }

    private func syncedState(_ peer: IPeer) -> Bool {
        syncedStates[peer.host] ?? false
    }

    private func blockHashesSyncedState(_ peer: IPeer) -> Bool {
        blockHashesSyncedStates[peer.host] ?? false
    }

    private func assignNextSyncPeer() {
        guard syncPeer == nil else {
            return
        }

        let nonSyncedPeers = peerManager.sorted.filter { !syncedState($0) }
        if nonSyncedPeers.isEmpty {
            subject.onNext(.onAllPeersSynced)
        }

        if let peer = nonSyncedPeers.first(where: { $0.ready }) {
            logger?.debug("Setting sync peer to \(peer.logName)")
            syncPeer = peer
            blockSyncer.downloadStarted()
            downloadBlockchain()
        }
    }

    private func downloadBlockchain() {
        guard let syncPeer = self.syncPeer, syncPeer.ready else {
            return
        }

        if selectNewPeer {
            selectNewPeer = false
            blockSyncer.downloadCompleted()
            self.syncPeer = nil
            assignNextSyncPeer()
            return
        }

        let blockHashes = blockSyncer.getBlockHashes()
        if blockHashes.isEmpty {
            syncedStates[syncPeer.host] = blockHashesSyncedStates[syncPeer.host]
        } else {
            syncPeer.add(task: GetMerkleBlocksTask(
                    blockHashes: blockHashes, merkleBlockValidator: merkleBlockValidator, merkleBlockHandler: self,
                    minMerkleBlocksCount: minMerkleBlocksCount, minTransactionsCount: minTransactionsCount, minTransactionsSize: minTransactionsSize))
        }

        if !blockHashesSyncedState(syncPeer) {
            let blockLocatorHashes = blockSyncer.getBlockLocatorHashes(peerLastBlockHeight: syncPeer.announcedLastBlockHeight)
            let expectedHashesMinCount = max(syncPeer.announcedLastBlockHeight - blockSyncer.localKnownBestBlockHeight, 0)

            syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes, expectedHashesMinCount: expectedHashesMinCount))
        }

        if syncedState(syncPeer) {
            self.syncPeer = nil
            setPeerSynced(syncPeer)
            blockSyncer.downloadCompleted()
            syncPeer.sendMempoolMessage()
            assignNextSyncPeer()
        }
    }

    private func resetRequiredDownloadSpeed() {
        minMerkleBlocksCount = 500
        minTransactionsCount = 50_000
        minTransactionsSize = 100_000
    }

    private func decreaseRequiredDownloadSpeed() {
        minMerkleBlocksCount = minMerkleBlocksCount / 3
        minTransactionsCount = minTransactionsCount / 3
        minTransactionsSize = minTransactionsSize / 3
    }

    private func setPeerSynced(_ peer: IPeer) {
        syncedStates[peer.host] = true
        blockHashesSyncedStates[peer.host] = true
        syncedPeers.append(peer)

        subject.onNext(.onPeerSynced(peer: peer))

        if blockSyncer.localDownloadedBestBlockHeight >= peer.announcedLastBlockHeight {
            // Some peers fail to send InventoryMessage within expected time
            // and become 'synced' in InitialBlockDownload without sending all of their blocks.
            // In such case, we assume not all blocks are downloaded
            listener?.blocksSyncFinished()
        }
    }

    private func setPeerNotSynced(_ peer: IPeer) {
        syncedStates[peer.host] = false
        blockHashesSyncedStates[peer.host] = false
        if let index = syncedPeers.firstIndex(where: { $0.equalTo(peer) }) {
            syncedPeers.remove(at: index)
        }
        subject.onNext(.onPeerNotSynced(peer: peer))
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

    public var hasSyncedPeer: Bool {
        syncedPeers.count > 0
    }

}

extension InitialBlockDownload: IInitialBlockDownload {

    public func isSynced(peer: IPeer) -> Bool {
        syncedState(peer)
    }

}

extension InitialBlockDownload: IInventoryItemsHandler {

    public func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        peersQueue.async {
            if self.syncedState(peer) && inventoryItems.first(where: { $0.type == InventoryItem.ObjectType.blockMessage.rawValue }) != nil {
                self.setPeerNotSynced(peer)
                self.assignNextSyncPeer()
            }
        }
    }

}

extension InitialBlockDownload: IPeerTaskHandler {

    public func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
        switch task {
        case let t as GetBlockHashesTask:
            if t.blockHashes.isEmpty {
                peersQueue.async {
                    self.blockHashesSyncedStates[peer.host] = true
                }
            } else {
                blockSyncer.add(blockHashes: t.blockHashes)
            }
            return true
        case is GetMerkleBlocksTask:
            blockSyncer.downloadIterationCompleted()
            return true
        default: return false
        }
    }

}

extension InitialBlockDownload {

    private func onStart() {
        resetRequiredDownloadSpeed()
        blockSyncer.prepareForDownload()
    }

    private func onStop() {
    }

    private func onPeerCreate(peer: IPeer) {
        peer.localBestBlockHeight = blockSyncer.localDownloadedBestBlockHeight
    }

    private func onPeerConnect(peer: IPeer) {
        peersQueue.async {
            self.syncedStates[peer.host] = false
            self.blockHashesSyncedStates[peer.host] = false
            if let syncPeer = self.syncPeer, syncPeer.connectionTime > peer.connectionTime * InitialBlockDownload.peerSwitchMinimumRatio {
                self.selectNewPeer = true
            }
            self.assignNextSyncPeer()
        }
    }

    private func onPeerDisconnect(peer: IPeer, error: Error?) {
        peersQueue.async {
            if error is GetMerkleBlocksTask.TooSlowPeer {
                self.slowPeersDisconnected += 1
                if self.slowPeersDisconnected >= 3 {
                    self.decreaseRequiredDownloadSpeed()
                    self.slowPeersDisconnected = 0
                }
            }

            if let index = self.syncedPeers.firstIndex(where: { $0.equalTo(peer) }) {
                self.syncedPeers.remove(at: index)
            }
            self.syncedStates.removeValue(forKey: peer.host)
            self.blockHashesSyncedStates.removeValue(forKey: peer.host)

            if peer.equalTo(self.syncPeer) {
                self.syncPeer = nil
                self.blockSyncer.downloadFailed()
                self.assignNextSyncPeer()
            }
        }
    }

    private func onPeerReady(peer: IPeer) {
        if peer.equalTo(syncPeer) {
            peersQueue.async {
                self.downloadBlockchain()
            }
        }
    }

}

extension InitialBlockDownload: IMerkleBlockHandler {

    func handle(merkleBlock: MerkleBlock) throws {
        let maxBlockHeight = syncPeer?.announcedLastBlockHeight ?? 0
        try blockSyncer.handle(merkleBlock: merkleBlock, maxBlockHeight: maxBlockHeight)
    }

}
