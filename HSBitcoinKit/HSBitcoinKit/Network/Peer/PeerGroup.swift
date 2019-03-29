import Foundation
import RxSwift

class PeerGroup {

    enum PeerGroupError: Error {
        case noConnectedPeers
        case peersNotSynced
    }

    private let reachabilityManager: IReachabilityManager
    private var disposable: Disposable?

    weak var blockSyncer: IBlockSyncer?
    weak var transactionSyncer: ITransactionSyncer?
    private var syncStateListener: ISyncStateListener

    private let factory: IFactory
    private let network: INetwork
    var networkMessageParser: INetworkMessageParser
    var networkMessageSerializer: INetworkMessageSerializer

    private var peerAddressManager: IPeerAddressManager
    private var bloomFilterManager: IBloomFilterManager
    private var peerCount: Int

    private var started: Bool = false
    private var _started: Bool = false

    private var peerManager: IPeerManager

    private let peersQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    private let logger: Logger?

    var inventoryItemsHandler: IInventoryItemsHandler? = nil
    var peerTaskHandler: IPeerTaskHandler? = nil

    var taskQueue = SynchronizedArray<PeerTask>()

    init(factory: IFactory, network: INetwork,
         networkMessageParser: INetworkMessageParser, networkMessageSerializer: INetworkMessageSerializer,
         listener: ISyncStateListener, reachabilityManager: IReachabilityManager,
         peerAddressManager: IPeerAddressManager, bloomFilterManager: IBloomFilterManager,
         peerCount: Int = 1, peerManager: IPeerManager = PeerManager(),
         peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background),
         logger: Logger? = nil) {
        self.factory = factory
        self.network = network
        self.networkMessageParser = networkMessageParser
        self.networkMessageSerializer = networkMessageSerializer

        self.syncStateListener = listener
        self.reachabilityManager = reachabilityManager
        self.peerAddressManager = peerAddressManager
        self.bloomFilterManager = bloomFilterManager
        self.peerCount = peerCount
        self.peerManager = peerManager

        self.peersQueue = peersQueue
        self.inventoryQueue = inventoryQueue

        self.logger = logger

        self.peerAddressManager.delegate = self
        self.bloomFilterManager.delegate = self
    }

    deinit {
        disposable?.dispose()
    }

    private func connectPeersIfRequired() {
        peersQueue.async {
            guard self.started, self.reachabilityManager.isReachable else {
                return
            }

            for _ in self.peerManager.totalPeersCount()..<self.peerCount {
                if let host = self.peerAddressManager.ip {
                    let peer = self.factory.peer(withHost: host, network: self.network, networkMessageParser: self.networkMessageParser, networkMessageSerializer: self.networkMessageSerializer, logger: self.logger)
                    peer.delegate = self
                    peer.localBestBlockHeight = self.blockSyncer?.localDownloadedBestBlockHeight ?? 0
                    self.peerManager.add(peer: peer)
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

    private func handlePendingTransactions() throws {
        try checkPeersSynced()

        peersQueue.async {
            for peer in self.peerManager.someReadyPeers() {
                let pendingTransactions = self.transactionSyncer?.pendingTransactions() ?? []
                for transaction in pendingTransactions {
                    peer.add(task: SendTransactionTask(transaction: transaction))
                }
            }
        }
    }

    private func downloadBlockchain() {
        peersQueue.async {
            guard let syncPeer = self.peerManager.syncPeer, syncPeer.ready else {
                return
            }

            if let blockHashes = self.blockSyncer?.getBlockHashes() {
                if (blockHashes.isEmpty) {
                    syncPeer.synced = syncPeer.blockHashesSynced
                } else {
                    syncPeer.add(task: GetMerkleBlocksTask(blockHashes: blockHashes))
                }
            }

            if !syncPeer.blockHashesSynced, let blockLocatorHashes = self.blockSyncer?.getBlockLocatorHashes(peerLastBlockHeight: syncPeer.announcedLastBlockHeight) {
                let expectedHashesMinCount: Int32!

                if let localKnownBestBlockHeight = self.blockSyncer?.localKnownBestBlockHeight, syncPeer.announcedLastBlockHeight > localKnownBestBlockHeight {
                    expectedHashesMinCount = syncPeer.announcedLastBlockHeight - localKnownBestBlockHeight
                } else {
                    expectedHashesMinCount = 0
                }

                syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes, expectedHashesMinCount: expectedHashesMinCount))
            }

            if syncPeer.synced {
                self.blockSyncer?.downloadCompleted()
                self.syncStateListener.syncFinished()
                syncPeer.sendMempoolMessage()
                self.peerManager.syncPeer = nil
                self.assignNextSyncPeer()
            }
        }
    }

    private func assignNextSyncPeer() {
        peersQueue.async {
            guard self.peerManager.syncPeer == nil else {
                return
            }

            if let nonSyncedPeer = self.peerManager.nonSyncedPeer() {
                self.logger?.debug("Setting sync peer to \(nonSyncedPeer.logName)")
                self.peerManager.syncPeer = nonSyncedPeer
                self.blockSyncer?.downloadStarted()
                self.downloadBlockchain()
            } else {
                try? self.handlePendingTransactions()
            }
        }
    }

    private func isRequestingInventory(hash: Data) -> Bool {
        for peer in self.peerManager.connected() {
            if peer.isRequestingInventory(hash: hash) {
                return true
            }
        }
        return false
    }

    private func handle(peer: IPeer, task: GetBlockHashesTask) {
        guard !task.blockHashes.isEmpty else {
            peer.blockHashesSynced = true
            return
        }

        blockSyncer?.add(blockHashes: task.blockHashes)
    }

    private func handle(peer: IPeer, task: GetMerkleBlocksTask) {
        self.blockSyncer?.downloadIterationCompleted()
    }

    private func handle(transactions: [FullTransaction]) {
        transactionSyncer?.handle(transactions: transactions)
    }

    private func handle(sentTransaction transaction: FullTransaction) {
        transactionSyncer?.handle(sentTransaction: transaction)
    }

    private func _start() {
        guard started, _started == false else {
            return
        }

        _started = true

        blockSyncer?.prepareForDownload()
        connectPeersIfRequired()
        syncStateListener.syncStarted()
    }

    private func _stop() {
        _started = false

        self.peerManager.disconnectAll()
        syncStateListener.syncStopped()
    }

}

extension PeerGroup: IPeerGroup {

    func start() {
        guard started == false else {
            return
        }

        started = true

        // Subscribe to ReachabilityManager
        disposable = reachabilityManager.reachabilitySignal.subscribe(onNext: { [weak self] in
            self?.onChangeConnection()
        })

        if reachabilityManager.isReachable {
            _start()
        }
    }

    private func onChangeConnection() {
        if reachabilityManager.isReachable {
            _start()
        } else {
            _stop()
        }
    }

    func stop() {
        started = false

        // Unsubscribe to ReachabilityManager
        disposable?.dispose()

        _stop()
    }

    func checkPeersSynced() throws {
        guard peerManager.connected().count > 0 else {
            throw PeerGroupError.noConnectedPeers
        }

        guard peerManager.nonSyncedPeer() == nil else {
            throw PeerGroupError.peersNotSynced
        }
    }

    func sendPendingTransactions() throws {
        try self.handlePendingTransactions()
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        self.downloadBlockchain()

        if let task = taskQueue.first {
            peer.add(task: task)
            taskQueue.remove(at: 0)
        }
    }

    func peerDidConnect(_ peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }

        self.assignNextSyncPeer()
    }

    func peerDidDisconnect(_ peer: IPeer, withError error: Error?) {
        if let error = error {
            logger?.warning("Peer \(peer.logName)(\(peer.host)) disconnected. Network reachable: \(reachabilityManager.isReachable). Error: \(error)")
        }

        if reachabilityManager.isReachable && error != nil {
            peerAddressManager.markFailed(ip: peer.host)
        } else {
            peerAddressManager.markSuccess(ip: peer.host)
        }

        peersQueue.async {
            self.peerManager.peerDisconnected(peer: peer)

            if self.peerManager.syncPeerIs(peer: peer) {
                self.blockSyncer?.downloadFailed()
                self.peerManager.syncPeer = nil
                self.assignNextSyncPeer()
            }
        }

        connectPeersIfRequired()
    }

    func peer(_ peer: IPeer, didCompleteTask task: PeerTask) {
        switch task {

        case let task as GetBlockHashesTask:
            handle(peer: peer, task: task)

        case let task as GetMerkleBlocksTask:
            handle(peer: peer, task: task)

        case let task as RequestTransactionsTask:
            handle(transactions: task.transactions)

        case let task as SendTransactionTask:
            handle(sentTransaction: task.transaction)

        default: peerTaskHandler?.handleCompletedTask(peer: peer, task: task)
        }
    }

    func handle(_ peer: IPeer, merkleBlock: MerkleBlock) {
        do {
            try blockSyncer?.handle(merkleBlock: merkleBlock, maxBlockHeight: peer.announcedLastBlockHeight)
        } catch {
            logger?.warning(error, context: peer.logName)
            peer.disconnect(error: error)
        }
    }

    func peer(_ peer: IPeer, didReceiveAddresses addresses: [NetworkAddress]) {
        self.peerAddressManager.add(ips: addresses.map {
            $0.address
        })
    }

    func peer(_ peer: IPeer, didReceiveInventoryItems items: [InventoryItem]) {
        inventoryQueue.async {
            var blockHashes = [Data]()
            var transactionHashes = [Data]()

            for item in items {
                switch item.objectType {
                case .blockMessage:
                    if self.blockSyncer?.shouldRequestBlock(withHash: item.hash) ?? false {
                        blockHashes.append(item.hash)
                    }
                case .transaction:
                    if !self.isRequestingInventory(hash: item.hash) {
                        if self.transactionSyncer?.shouldRequestTransaction(hash: item.hash) ?? false {
                            transactionHashes.append(item.hash)
                        }
                    }
                default: ()
                }
            }

            if !blockHashes.isEmpty, peer.synced {
                peer.synced = false
                peer.blockHashesSynced = false
                self.assignNextSyncPeer()
            }

            if !transactionHashes.isEmpty {
                peer.add(task: RequestTransactionsTask(hashes: transactionHashes))
            }
            self.inventoryItemsHandler?.handleInventoryItems(peer: peer, inventoryItems: items)
        }
    }

    func addTask(peerTask: PeerTask) {
        // todo find better solution
        if let peer = peerManager.someReadyPeers().first {
            peer.add(task: peerTask)
        } else {
            taskQueue.append(peerTask)
        }

    }

}

extension PeerGroup: IPeerAddressManagerDelegate {

    func newIpsAdded() {
        connectPeersIfRequired()
    }

}

extension PeerGroup: BloomFilterManagerDelegate {

    func bloomFilterUpdated(bloomFilter: BloomFilter) {
        for peer in self.peerManager.connected() {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

}
