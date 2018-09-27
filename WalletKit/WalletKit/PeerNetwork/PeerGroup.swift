import Foundation
import RealmSwift
import RxSwift

class PeerGroup {

    private let blocksPerWindow: Int = 1000
    private let blocksPerPeer: Int = 100

    weak var headersSyncer: IHeaderSyncer?
    weak var blockSyncer: IBlockSyncer?
    weak var transactionSyncer: ITransactionSyncer?

    private let network: NetworkProtocol
    private let peerHostManager: PeerHostManager
    private var bloomFilters: [Data]
    private var peerCount: Int

    private var started: Bool = false

    private var peers: [Peer] = []
    private var syncPeer: Peer?

    private var requestedBlockHashes: [Data] = []
    private var fetchedBlocks: [MerkleBlock] = []

    private var pendingBlockHashes: [Data] = []
    private var pendingTransactions: [Transaction] = []

    private let localQueue: DispatchQueue
    private let syncPeerQueue: DispatchQueue
    private let inventoryQueue: DispatchQueue

    init(network: NetworkProtocol, peerHostManager: PeerHostManager, bloomFilters: [Data], peerCount: Int = 10) {
        self.network = network
        self.peerHostManager = peerHostManager
        self.bloomFilters = bloomFilters
        self.peerCount = peerCount

        localQueue = DispatchQueue(label: "PeerGroup Local Queue", qos: .userInitiated)
        syncPeerQueue = DispatchQueue(label: "PeerGroup Sync Peer Queue", qos: .userInitiated)
        inventoryQueue = DispatchQueue(label: "PeerGroup Inventory Queue", qos: .background)

        self.peerHostManager.delegate = self
    }

    func start() {
        guard started == false else {
            return
        }

        started = true

        addNonSentTransactions()
        dispatchRequestedBlocks()
        connectPeersIfRequired()
    }

    func stop() {
        started = false

        for peer in peers {
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

    func addPublicKeyFilter(pubKey: PublicKey) {
        if !bloomFilters.contains(pubKey.raw!) {
            bloomFilters.append(pubKey.keyHash)
            bloomFilters.append(pubKey.raw!)
        }

        for peer in peers {
            peer.addFilter(filter: pubKey.keyHash)
            peer.addFilter(filter: pubKey.raw!)
        }
    }

    private func connectPeersIfRequired() {
        localQueue.async {
            guard self.started else {
                return
            }

            for _ in self.peers.count..<self.peerCount {
                if let host = self.peerHostManager.peerHost {
                    let peer = Peer(host: host, network: self.network)
                    self.peers.append(peer)
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
            for peer in peers.filter({ $0.ready }) {
                handleReady(peer: peer)
            }
        }
    }

    private func handleReady(peer: Peer) {
        guard peer.ready else {
            return
        }

        for transaction in pendingTransactions {
            peer.add(task: RelayTransactionPeerTask(transaction: transaction))
        }
        pendingTransactions = []

        let hashes = Array(pendingBlockHashes.prefix(blocksPerPeer))

        if !hashes.isEmpty {
            pendingBlockHashes.removeFirst(hashes.count)
            peer.add(task: RequestMerkleBlocksPeerTask(hashes: hashes))

            Logger.shared.log(self, "Dispatching \(hashes.count) blocks to \(peer.logName)")
        }
    }

    private func handleReadySyncPeer() {
        if let hashes = self.headersSyncer?.getHashes() {
            self.syncPeer?.add(task: RequestHeadersPeerTask(hashes: hashes))
        }
    }

    private func isRequestingInventory(hash: Data) -> Bool {
        for peer in peers {
            if peer.isRequestingInventory(hash: hash) {
                return true
            }
        }
        return false
    }

    private func handleRelayedTransaction(hash: Data) -> Bool {
        for peer in peers {
            if peer.handleRelayedTransaction(hash: hash) {
                return true
            }
        }
        return false
    }

    private func handle(blockHeaders: [BlockHeader]) {
        syncPeerQueue.async {
            try? self.headersSyncer?.handle(headers: blockHeaders)

            if blockHeaders.count < 2000 {
                Logger.shared.log(self, "Unsetting sync peer from \(self.syncPeer?.logName ?? "")")
                self.syncPeer?.headersSynced = true
                self.syncPeer = nil

                self.assignNextSyncPeer()
            } else {
                self.handleReadySyncPeer()
            }

            if !blockHeaders.isEmpty {
                self.dispatchRequestedBlocks()
            }
        }
    }

    private func dispatchRequestedBlocks() {
        localQueue.async {
            if self.requestedBlockHashes.isEmpty {
                self.fetchRequestedBlockHashes()
            }
        }
    }

    private func fetchRequestedBlockHashes(hash: Data? = nil) {
        if let hashes = self.blockSyncer?.getHashes(afterHash: hash, limit: self.blocksPerWindow) {
            self.requestedBlockHashes = hashes
            self.pendingBlockHashes = hashes
            self.dispatchTasks()
        }
    }

    private func handle(merkleBlocks: [MerkleBlock]) {
        localQueue.async {
            var requestedBlocks = [MerkleBlock]()
            var newBlocks = [MerkleBlock]()

            for block in merkleBlocks {
                if self.requestedBlockHashes.contains(block.headerHash) {
                    requestedBlocks.append(block)
                } else {
                    newBlocks.append(block)
                }
            }

            if !newBlocks.isEmpty {
                self.blockSyncer?.handle(merkleBlocks: newBlocks)
            }

            if !requestedBlocks.isEmpty {
                self.fetchedBlocks.append(contentsOf: requestedBlocks)

                if self.requestedBlockHashes.count == self.fetchedBlocks.count {
                    let blocks = self.fetchedBlocks
                    self.fetchedBlocks = []

                    Logger.shared.log(self, "Handle \(blocks.count) blocks")
                    self.blockSyncer?.handle(merkleBlocks: blocks)

                    if let hash = self.requestedBlockHashes.last {
                        self.fetchRequestedBlockHashes(hash: hash)
                    } else {
                        self.requestedBlockHashes = []
                    }
                }
            }
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
        guard syncPeer == nil else {
            return
        }

        if let nonSyncedPeer = peers.first(where: { $0.connected && !$0.headersSynced }) {
            Logger.shared.log(self, "Setting sync peer to \(nonSyncedPeer.logName)")
            syncPeer = nonSyncedPeer
            handleReadySyncPeer()
        }
    }

}

extension PeerGroup: PeerDelegate {

    func getBloomFilters() -> [Data] {
        return bloomFilters
    }

    func peerReady(_ peer: Peer) {
        localQueue.async {
            self.dispatchTasks(forReadyPeer: peer)
        }
    }

    func peerDidConnect(_ peer: Peer) {
        syncPeerQueue.async {
            self.assignNextSyncPeer()
        }
    }

    func peerDidDisconnect(_ peer: Peer, withError error: Bool) {
        if error {
            Logger.shared.log(self, "Peer with IP \(peer.host) disconnected with error")
        }

        peerHostManager.hostDisconnected(host: peer.host, withError: error)

        localQueue.async {
            if peer === self.syncPeer {
                self.syncPeer = nil
            }

            if let index = self.peers.index(where: { $0 === peer }) {
                self.peers.remove(at: index)
            }
        }

        connectPeersIfRequired()
    }

    func peer(_ peer: Peer, didHandleTask task: PeerTask) {
        guard task.completed else {
            // todo: handle failed task
            return
        }

        switch task {

        case let task as RequestHeadersPeerTask:
            handle(blockHeaders: task.blockHeaders)

        case let task as RequestMerkleBlocksPeerTask:
            Logger.shared.log(self, "Got \(task.merkleBlocks.count) from \(peer.logName)")
            handle(merkleBlocks: task.merkleBlocks)

        case let task as RequestTransactionsPeerTask:
            handle(transactions: task.transactions)

        case let task as RelayTransactionPeerTask:
            handle(relayedTransaction: task.transaction)

        default: ()

        }
    }

    func peer(_ peer: Peer, didReceiveAddresses addresses: [NetworkAddress]) {
        self.peerHostManager.addHosts(hosts: addresses.map { $0.address })
    }

    func peer(_ peer: Peer, didReceiveInventoryItems items: [InventoryItem]) {
        inventoryQueue.async {
            var blockHashes = [Data]()
            var transactionHashes = [Data]()

            for item in items {
                if !self.isRequestingInventory(hash: item.hash) {
                    switch item.objectType {
                    case .blockMessage:
                        if let blockSyncer = self.blockSyncer, blockSyncer.shouldRequestBlock(hash: item.hash) {
                            blockHashes.append(item.hash)
                        }
                    case .transaction:
                        if self.handleRelayedTransaction(hash: item.hash) {
                            continue
                        }

                        if let transactionSyncer = self.transactionSyncer, transactionSyncer.shouldRequestTransaction(hash: item.hash) {
                            transactionHashes.append(item.hash)
                        }
                    default: ()
                    }
                }
            }

            if !blockHashes.isEmpty {
                peer.add(task: RequestMerkleBlocksPeerTask(hashes: blockHashes))
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
