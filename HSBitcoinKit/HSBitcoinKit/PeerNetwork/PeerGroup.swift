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

    private var peerManager: IPeerManager

    private let peersQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    init(factory: IFactory, network: INetwork, listener: BestBlockHeightListener, reachabilityManager: IReachabilityManager,
         peerHostManager: IPeerHostManager, bloomFilterManager: IBloomFilterManager,
         peerCount: Int = 10, peerManager: IPeerManager = PeerManager(),
         peersQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)) {
        self.factory = factory
        self.network = network
        self.bestBlockHeightListener = listener
        self.reachabilityManager = reachabilityManager
        self.peerHostManager = peerHostManager
        self.bloomFilterManager = bloomFilterManager
        self.peerCount = peerCount
        self.peerManager = peerManager

        self.peersQueue = peersQueue
        self.inventoryQueue = inventoryQueue

        self.peerHostManager.delegate = self
        self.bloomFilterManager.delegate = self
    }

    deinit {
        disposable?.dispose()
    }

    private func connectPeersIfRequired() {
        peersQueue.async {
            guard self.started, self.reachabilityManager.reachable() else {
                return
            }

            for _ in self.peerManager.totalPeersCount()..<self.peerCount {
                if let host = self.peerHostManager.peerHost {
                    let peer = self.factory.peer(withHost: host, network: self.network)
                    peer.delegate = self
                    peer.localBestBlockHeight = self.blockSyncer?.localBestBlockHeight ?? 0
                    self.peerManager.add(peer: peer)
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

    private func handlePendingTransactions() {
        peersQueue.async {
            guard self.peerManager.connected().count > 0, self.peerManager.nonSyncedPeer() == nil else {
                return
            }

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
                syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes))
            }

            if syncPeer.synced {
                self.blockSyncer?.downloadCompleted()
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
                Logger.shared.log(self, "Setting sync peer to \(nonSyncedPeer.logName)")
                self.peerManager.syncPeer = nonSyncedPeer
                self.blockSyncer?.downloadStarted()
                self.bestBlockHeightListener.bestBlockHeightReceived(height: nonSyncedPeer.announcedLastBlockHeight)
                self.downloadBlockchain()
            } else {
                self.handlePendingTransactions()
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

    private func handle(transactions: [Transaction]) {
        transactionSyncer?.handle(transactions: transactions)
    }

    private func handle(sentTransaction transaction: Transaction) {
        transactionSyncer?.handle(sentTransaction: transaction)
    }

    private func _start() {
        guard started, _started == false else {
            return
        }

        _started = true

        blockSyncer?.prepareForDownload()
        connectPeersIfRequired()
    }

    private func _stop() {
        _started = false

        self.peerManager.disconnectAll()
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

    func sendPendingTransactions() {
        self.handlePendingTransactions()
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: IPeer) {
        Logger.shared.log(self, "Handling peerReady: \(peer.logName)")
        self.downloadBlockchain()
    }

    func peerDidConnect(_ peer: IPeer) {
        if let bloomFilter = bloomFilterManager.bloomFilter {
            peer.filterLoad(bloomFilter: bloomFilter)
        }

        self.assignNextSyncPeer()
    }

    func peerDidDisconnect(_ peer: IPeer, withError error: Error?) {
        if let error = error {
            Logger.shared.log(self, "Peer \(peer.logName)(\(peer.host)) disconnected. Network reachable: \(reachabilityManager.reachable()). Error: \(error)")
        }

        peerHostManager.hostDisconnected(host: peer.host, withError: error, networkReachable: reachabilityManager.reachable())

        peersQueue.async {
            if self.peerManager.syncPeerIs(peer: peer) {
                self.blockSyncer?.downloadFailed()
                self.peerManager.syncPeer = nil
                self.assignNextSyncPeer()
            }

            self.peerManager.peerDisconnected(peer: peer)
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
        for peer in self.peerManager.connected() {
            peer.filterLoad(bloomFilter: bloomFilter)
        }
    }

}
