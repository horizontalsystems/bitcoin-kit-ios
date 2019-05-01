public class InitialBlockDownload {
    private var blockSyncer: IBlockSyncer?
    private let peerManager: IPeerManager
    private let syncStateListener: ISyncStateListener
    private var peerSyncListeners = [IPeerSyncListener]()

    private var syncPeer: IPeer?
    private let peersQueue: DispatchQueue
    private let logger: Logger?

    public var syncedPeers = [IPeer]()

    init(blockSyncer: IBlockSyncer?, peerManager: IPeerManager, syncStateListener: ISyncStateListener, peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated), logger: Logger? = nil) {
        self.blockSyncer = blockSyncer
        self.peerManager = peerManager
        self.syncStateListener = syncStateListener
        self.peersQueue = peersQueue
        self.logger = logger
    }

    private func assignNextSyncPeer() {
        peersQueue.async {
            guard self.syncPeer == nil else {
                return
            }

            let nonSyncedPeers = self.peerManager.connected().filter { !$0.synced }
            if nonSyncedPeers.isEmpty {
                self.peerSyncListeners.forEach { $0.onAllPeersSynced() }
            }

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
                syncPeer.synced = syncPeer.blockHashesSynced
            } else {
                syncPeer.add(task: GetMerkleBlocksTask(blockHashes: blockHashes, merkleBlockHandler: self))
            }

            if !syncPeer.blockHashesSynced {
                let blockLocatorHashes = blockSyncer.getBlockLocatorHashes(peerLastBlockHeight: syncPeer.announcedLastBlockHeight)
                let expectedHashesMinCount = max(syncPeer.announcedLastBlockHeight - blockSyncer.localKnownBestBlockHeight, 0)

                syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes, expectedHashesMinCount: expectedHashesMinCount))
            }

            if syncPeer.synced {
                self.syncedPeers.append(syncPeer)
                blockSyncer.downloadCompleted()
                self.syncStateListener.syncFinished()
                syncPeer.sendMempoolMessage()
                self.syncPeer = nil
                self.peerSyncListeners.forEach { $0.onPeerSynced(peer: syncPeer) }
                self.assignNextSyncPeer()
            }
        }
    }

}

extension InitialBlockDownload: IInitialBlockDownload {

    public func add(peerSyncListener: IPeerSyncListener) {
        peerSyncListeners.append(peerSyncListener)
    }

}

extension InitialBlockDownload: IInventoryItemsHandler {

    public func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        if peer.synced, inventoryItems.first(where: { $0.type == InventoryItem.ObjectType.blockMessage.rawValue }) != nil {
            peer.synced = false
            peer.blockHashesSynced = false
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
                peer.blockHashesSynced = true
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

extension InitialBlockDownload: IPeerGroupListener {

    public func onStart() {
        syncStateListener.syncStarted()
        blockSyncer?.prepareForDownload()
    }

    public func onStop() {
        syncStateListener.syncStopped()
        // set blockSyncer to null to make sure that there won't be any further interaction with blockSyncer
        // todo: check it's valid
        blockSyncer = nil
    }

    public func onPeerCreate(peer: IPeer) {
        peer.localBestBlockHeight = blockSyncer?.localDownloadedBestBlockHeight ?? 0
    }

    public func onPeerConnect(peer: IPeer) {
        assignNextSyncPeer()
    }

    public func onPeerDisconnect(peer: IPeer, error: Error?) {
        if let index = syncedPeers.index(where: { $0.equalTo(peer) }) {
            syncedPeers.remove(at: index)
        }

        if peer.equalTo(syncPeer) {
            syncPeer = nil
            blockSyncer?.downloadFailed()
            assignNextSyncPeer()
        }
    }

    public func onPeerReady(peer: IPeer) {
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
