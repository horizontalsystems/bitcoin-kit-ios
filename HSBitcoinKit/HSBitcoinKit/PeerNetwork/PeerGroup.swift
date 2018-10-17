import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    weak var blockSyncer: BlockSyncer?
    weak var transactionSyncer: ITransactionSyncer?

    private let factory: Factory
    private let network: NetworkProtocol
    private let peerHostManager: PeerHostManager
    private var bloomFilterManager: BloomFilterManager
    private var peerCount: Int

    private var started: Bool = false

    private var connectedPeers: [Peer] = []
    private var connectingPeerHosts: [Peer] = []
    private var syncPeer: Peer?

    private var fetchedBlocks: [MerkleBlock] = []
    private var pendingTransactions: [Transaction] = []

    private let localQueue: DispatchQueue
    private let syncPeerQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    init(factory: Factory, network: NetworkProtocol, peerHostManager: PeerHostManager, bloomFilterManager: BloomFilterManager, peerCount: Int = 10,
         localQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated),
         syncPeerQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Sync Peer Queue", qos: .userInitiated),
         inventoryQueue: DispatchQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)) {
        self.factory = factory
        self.network = network
        self.peerHostManager = peerHostManager
        self.bloomFilterManager = bloomFilterManager
        self.peerCount = peerCount

        self.localQueue = localQueue
        self.syncPeerQueue = syncPeerQueue
        self.inventoryQueue = inventoryQueue

        self.peerHostManager.delegate = self
        self.bloomFilterManager.delegate = self
    }

    func start() {
        guard started == false else {
            return
        }

        started = true

        addNonSentTransactions()
        connectPeersIfRequired()
    }

    func stop() {
        started = false

        for peer in connectedPeers {
            peer.disconnect()
        }
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

    private func connectPeersIfRequired() {
        localQueue.async {
            guard self.started else {
                return
            }

            for _ in (self.connectedPeers.count+self.connectingPeerHosts.count)..<self.peerCount {
                if let host = self.peerHostManager.peerHost {
                    let peer = self.factory.peer(withHost: host, network: self.network)
                    self.connectingPeerHosts.append(peer)
                    peer.delegate = self
                    peer.connect()
                } else {
                    break
                }
            }
        }
    }

    private func dispatchTasks(forReadyPeer peer: Peer? = nil) {
        if let peer = peer {
            handleReady(peer: peer)
        } else {
            for peer in connectedPeers.filter({ $0.ready }) {
                handleReady(peer: peer)
            }
        }
    }

    private func handleReady(peer: Peer) {
        guard peer.ready else {
            return
        }

        if peer == syncPeer {
            downloadBlockchain()
            return
        }

        for transaction in pendingTransactions {
            peer.add(task: RelayTransactionPeerTask(transaction: transaction))
        }
        pendingTransactions = []
    }

    private func downloadBlockchain() {
        guard let syncPeer = self.syncPeer, syncPeer.ready else {
            return
        }

        if let listHashes = self.blockSyncer?.getBlockHashes() {
            if (listHashes.isEmpty) {
                syncPeer.synced = syncPeer.blockHashesSynced
            } else {
                syncPeer.add(task: GetMerkleBlocksTask(hashes: listHashes))
            }
        }

        if !syncPeer.blockHashesSynced, let blockLocatorHashes = self.blockSyncer?.getBlockLocatorHashes() {
            syncPeer.add(task: GetBlockHashesTask(hashes: blockLocatorHashes))
        }

        if syncPeer.synced {
            Logger.shared.log(self, "Unsetting sync peer from \(syncPeer.logName)")
            self.syncPeer = nil
            assignNextSyncPeer()
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

    private func handle(peer: Peer, task: GetBlockHashesTask) {
        guard !task.blockHashes.isEmpty else {
            peer.blockHashesSynced = true
            return
        }

        blockSyncer?.add(blockHashes: task.blockHashes)
    }

    private func handle(peer: Peer, task: GetMerkleBlocksTask) {
        do {
            try self.blockSyncer?.merkleBlocksDownloadCompleted()
        } catch {
            peer.disconnect()
        }
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

    private func assignNextSyncPeer() {
        syncPeerQueue.async {
            guard self.syncPeer == nil else {
                return
            }

            if let nonSyncedPeer = self.connectedPeers.first(where: { !$0.synced }) {
                Logger.shared.log(self, "Setting sync peer to \(nonSyncedPeer.logName)")
                self.syncPeer = nonSyncedPeer
                self.downloadBlockchain()
            }
        }
    }

}

extension PeerGroup: PeerDelegate {

    func peerReady(_ peer: Peer) {
        Logger.shared.log(self, "Handling peerReady: \(peer.logName)")
        localQueue.async {
            self.dispatchTasks(forReadyPeer: peer)
        }
    }

    func peerDidConnect(_ peer: Peer) {
        print("Peer \(peer.logName) didConnect")
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

    func peerDidDisconnect(_ peer: Peer, withError error: Bool) {
        if error {
            Logger.shared.log(self, "Peer with IP \(peer.host) disconnected with error")
        }

        peerHostManager.hostDisconnected(host: peer.host, withError: error)

        localQueue.async {
            self.syncPeerQueue.async {
                if peer === self.syncPeer {
                    self.syncPeer = nil
                    self.blockSyncer?.clearBlockHashes()
                }
            }

            if let index = self.connectedPeers.index(where: { $0 === peer }) {
                self.connectedPeers.remove(at: index)
            }
        }

        connectPeersIfRequired()
    }

    func peer(_ peer: Peer, didCompleteTask task: PeerTask) {
        switch task {

        case let task as GetBlockHashesTask:
            handle(peer: peer, task: task)

        case let task as GetMerkleBlocksTask:
            handle(peer: peer, task: task)

        case let task as RequestTransactionsPeerTask:
            handle(transactions: task.transactions)

        case let task as RelayTransactionPeerTask:
            handle(relayedTransaction: task.transaction)

        default: ()

        }
    }

    func handle(_ peer: Peer, merkleBlock: MerkleBlock, fullBlock: Bool) throws {
        do {
            try blockSyncer?.handle(merkleBlock: merkleBlock, fullBlock: fullBlock)
        } catch let error as BlockSyncer.BlockSyncerError {
            throw error
        } catch {
            peer.disconnect()
        }
    }

    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress]) {
        self.peerHostManager.addHosts(hosts: addresses.map {
            $0.address
        })
    }

    func peer(_ peer: Peer, didReceiveInventoryItems items: [InventoryItem]) {
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
                peer.add(task: RequestTransactionsPeerTask(hashes: transactionHashes))
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
