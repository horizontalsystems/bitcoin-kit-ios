class InitialBlockDownload {
    private var blockSyncer: IBlockSyncer?
    private let peerManager: IPeerManager
    private let syncStateListener: ISyncStateListener

    var peerSyncedDelegate: IAllPeersSyncedDelegate?

    private var syncPeer: IPeer?
    private let peersQueue: DispatchQueue
    private let logger: Logger?

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

            if let nonSyncedPeer = self.peerManager.nonSyncedPeer() {
                self.logger?.debug("Setting sync peer to \(nonSyncedPeer.logName)")
                self.syncPeer = nonSyncedPeer
                self.blockSyncer?.downloadStarted()
                self.downloadBlockchain()
            } else {
                self.peerSyncedDelegate?.onAllPeersSynced()
            }
        }
    }

    private func downloadBlockchain() {
        peersQueue.async {
            guard let syncPeer = self.syncPeer, syncPeer.ready, let blockSyncer = self.blockSyncer, syncPeer.ready else {
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
                blockSyncer.downloadCompleted()
                self.syncStateListener.syncFinished()
                syncPeer.sendMempoolMessage()
                self.syncPeer = nil
                self.assignNextSyncPeer()
            }
        }
    }

}

extension InitialBlockDownload: IInventoryItemsHandler {

    func handleInventoryItems(peer: IPeer, inventoryItems: [InventoryItem]) {
        if peer.synced, inventoryItems.first(where: { $0.type == InventoryItem.ObjectType.blockMessage.rawValue }) != nil {
            peer.synced = false
            peer.blockHashesSynced = false
            assignNextSyncPeer()
        }
    }

}

extension InitialBlockDownload: IPeerTaskHandler {

    func handleCompletedTask(peer: IPeer, task: PeerTask) -> Bool {
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

    func onStart() {
        syncStateListener.syncStarted()
        blockSyncer?.prepareForDownload()
    }

    func onStop() {
        syncStateListener.syncStopped()
        // set blockSyncer to null to make sure that there won't be any further interaction with blockSyncer
        // todo: check it's valid
        blockSyncer = nil
    }

    func onPeerCreate(peer: IPeer) {
        peer.localBestBlockHeight = blockSyncer?.localDownloadedBestBlockHeight ?? 0
    }

    func onPeerConnect(peer: IPeer) {
        assignNextSyncPeer()
    }

    func onPeerDisconnect(peer: IPeer, error: Error?) {
        if peer.equalTo(syncPeer) {
            syncPeer = nil
            blockSyncer?.downloadFailed()
            assignNextSyncPeer()
        }
    }

    func onPeerReady(peer: IPeer) {
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
