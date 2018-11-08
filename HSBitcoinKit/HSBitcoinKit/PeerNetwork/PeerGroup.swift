import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    private let reachabilityManager: IReachabilityManager
    private var disposable: Disposable?

    weak var blockSyncer: IBlockSyncer?
    weak var transactionSyncer: ITransactionSyncer?
    private var bestBlockHeightListener: BestBlockHeightListener

    private let factory: IFactory
    private let network: INetwork
    private var peerHostManager: IPeerHostManager
    private var bloomFilterManager: IBloomFilterManager
    private var peerCount: Int

    private var started: Bool = false
    private var _started: Bool = false

    private var connectedPeers: [IPeer] = []
    private var connectingPeerHosts: [IPeer] = []
    private var syncPeer: IPeer?

    private var fetchedBlocks: [MerkleBlock] = []
    private var pendingTransactions: [Transaction] = []

    private let localQueue: DispatchQueue
    private let syncPeerQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    init(factory: IFactory, network: INetwork, listener: BestBlockHeightListener, reachabilityManager: IReachabilityManager,
         peerHostManager: IPeerHostManager, bloomFilterManager: IBloomFilterManager, peerCount: Int = 10,
         localQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         syncPeerQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Sync Peer Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)) {
        self.factory = factory
        self.network = network
        self.bestBlockHeightListener = listener
        self.reachabilityManager = reachabilityManager
        self.peerHostManager = peerHostManager
        self.bloomFilterManager = bloomFilterManager
        self.peerCount = peerCount

        self.localQueue = localQueue
        self.syncPeerQueue = syncPeerQueue
        self.inventoryQueue = inventoryQueue

        self.peerHostManager.delegate = self
        self.bloomFilterManager.delegate = self
    }

    deinit {
        disposable?.dispose()
    }

    private func connectPeersIfRequired() {
        localQueue.async {
            guard self.started, self.reachabilityManager.reachable() else {
                return
            }

            for _ in (self.connectedPeers.count + self.connectingPeerHosts.count)..<self.peerCount {
                if let host = self.peerHostManager.peerHost {
                    let peer = self.factory.peer(withHost: host, network: self.network)
                    self.connectingPeerHosts.append(peer)
                    peer.localBestBlockHeight = self.blockSyncer?.localBestBlockHeight ?? 0
                    peer.delegate = self
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

    private func dispatchTasks(forReadyPeer peer: IPeer? = nil) {
        localQueue.async {
            if let peer = peer {
                self.handleReady(peer: peer)
            } else {
                for peer in self.connectedPeers.filter({ $0.ready }) {
                    self.handleReady(peer: peer)
                }
            }
        }
    }

    // Must be called only from DispatchTasks or localQueue thread
    private func handleReady(peer: IPeer) {
        guard peer.ready else {
            return
        }

        syncPeerQueue.async {
            if peer.equalTo(self.syncPeer) {
                self.downloadBlockchain()
                return
            }
        }

        for transaction in pendingTransactions {
            peer.add(task: RelayTransactionTask(transaction: transaction))
        }
        pendingTransactions = []
    }

    private func downloadBlockchain() {
        syncPeerQueue.async {
            guard let syncPeer = self.syncPeer, syncPeer.ready else {
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
                syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes))
            }

            if syncPeer.synced {
                self.blockSyncer?.downloadCompleted()
                syncPeer.sendMempoolMessage()
                self.syncPeer = nil
                self.assignNextSyncPeer()
            }
        }
    }

    private func assignNextSyncPeer() {
        syncPeerQueue.async {
            guard self.syncPeer == nil else {
                return
            }

            self.localQueue.async {
                if let nonSyncedPeer = self.connectedPeers.first(where: { !$0.synced }) {
                    Logger.shared.log(self, "Setting sync peer to \(nonSyncedPeer.logName)")
                    self.syncPeer = nonSyncedPeer
                    self.blockSyncer?.downloadStarted()
                    self.bestBlockHeightListener.bestBlockHeightReceived(height: nonSyncedPeer.announcedLastBlockHeight)
                    self.downloadBlockchain()
                }
            }
        }
    }

    private func isRequestingInventory(hash: Data) -> Bool {
        for peer in connectedPeers {
            if peer.isRequestingInventory(hash: hash) {
                return true
            }
        }
        return false
    }

    private func handleRelayedTransaction(hash: Data) -> Bool {
        for peer in connectedPeers {
            if peer.handleRelayedTransaction(hash: hash) {
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

    private func handle(transactions: [Transaction]) {
        transactionSyncer?.handle(transactions: transactions)
    }

    private func handle(relayedTransaction transaction: Transaction) {
        // todo: temp solution for setting tx status. It should be handled in more efficient way
        transactionSyncer?.handle(transactions: [transaction])
    }

    private func addNonSentTransactions() {
        if let transactions = transactionSyncer?.getNonSentTransactions() {
            for transaction in transactions {
                send(transaction: transaction)
            }
        }
    }

    private func _start() {
        guard started, _started == false else {
            return
        }

        _started = true

        addNonSentTransactions()
        blockSyncer?.prepareForDownload()
        connectPeersIfRequired()
    }

    private func _stop() {
        _started = false

        for peer in connectedPeers {
            peer.disconnect(error: nil)
        }

        for peer in connectingPeerHosts {
            peer.disconnect(error: nil)
        }
    }

}

extension PeerGroup: IPeerGroup {

    func start() {
        guard started == false else {
            return
        }

        started = true

        // Subscribe to ReachabilityManager
        disposable = reachabilityManager.subject.subscribe(onNext: { [weak self] status in
            if status == .reachable(.ethernetOrWiFi) || status == .reachable(.wwan) {
                self?._start()
            } else if status == .notReachable {
                self?._stop()
            }
        })

        if reachabilityManager.reachable() {
            _start()
        }
    }

    func stop() {
        started = false

        // Unsubscribe to ReachabilityManager
        disposable?.dispose()

        _stop()
    }

    func send(transaction: Transaction) {
        // Transaction is managed by Realm. We need to serialize and deserialize it in order to make it non-managed.
        let data = TransactionSerializer.serialize(transaction: transaction)
        let transaction = TransactionSerializer.deserialize(data: data)

        localQueue.async {
            self.pendingTransactions.append(transaction)
            self.dispatchTasks()
        }
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        Logger.shared.log(self, "Handling peerReady: \(peer.logName)")
        self.dispatchTasks(forReadyPeer: peer)
    }

    func peerDidConnect(_ peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }

        localQueue.async {
            if let index = self.connectingPeerHosts.index(where: { $0 === peer }) {
                self.connectingPeerHosts.remove(at: index)
            }
            self.connectedPeers.append(peer)
        }

        self.assignNextSyncPeer()
    }

    func peerDidDisconnect(_ peer: IPeer, withError error: Error?) {
        if let error = error {
            Logger.shared.log(self, "Peer \(peer.logName)(\(peer.host)) disconnected. Network reachable: \(reachabilityManager.reachable()). Error: \(error)")
        }

        peerHostManager.hostDisconnected(host: peer.host, withError: error, networkReachable: reachabilityManager.reachable())

        syncPeerQueue.async {
            if peer.equalTo(self.syncPeer) {
                self.blockSyncer?.downloadFailed()
                self.syncPeer = nil
                self.assignNextSyncPeer()
            }
        }

        localQueue.async {
            if let index = self.connectedPeers.index(where: { $0.equalTo(peer) }) {
                self.connectedPeers.remove(at: index)
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

        case let task as RelayTransactionTask:
            handle(relayedTransaction: task.transaction)

        default: ()

        }
    }

    func handle(_ peer: IPeer, merkleBlock: MerkleBlock) {
        do {
            try blockSyncer?.handle(merkleBlock: merkleBlock)
        } catch {
            peer.disconnect(error: error)
        }
    }

    func peer(_ peer: IPeer, didReceiveAddresses addresses: [NetworkAddress]) {
        self.peerHostManager.addHosts(hosts: addresses.map {
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
                        if self.handleRelayedTransaction(hash: item.hash) {
                            continue
                        }

                        if let transactionSyncer = self.transactionSyncer, transactionSyncer.shouldRequestTransaction(hash: item.hash) {
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
        }
    }
}

extension PeerGroup: PeerHostManagerDelegate {

    func newHostsAdded() {
        connectPeersIfRequired()
    }

}

extension PeerGroup: BloomFilterManagerDelegate {

    func bloomFilterUpdated(bloomFilter: BloomFilter) {
        for peer in self.connectedPeers {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

}
